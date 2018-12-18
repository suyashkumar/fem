function makeLoadsTemps(InputName,NormName,IsppaNorm,PulseDuration,cv,ElementVolume,sym,LCID, angle_deg);
%function makeLoadsTemps(InputName,NormName,IsppaNorm,PulseDuration,cv,ElementVolume,sym,LCID,angle_deg);
%
% INPUTS:
% InputName (string) - dyna*.mat file to process
% NormName (string) - dyna*.mat file with known Isppa 
% IsppaNorm (float) - Isppa value for the normalization file (W/cm^2)
% PulseDuration (float) - pulse duration (us)
% cv (float) - specific heat (4.2 W s / cm^3 / C)
% ElementVolume (float or char string) - element volume (cm^3) or path to
%                                        NodeVolume file that Andy creates
% sym (string) - symmetry boundary conditions
%                'q' -> quarter symmetry
%                'h' -> half symmetry
% LCID - load curve ID for the point loads
% angle_def - angle to direct the point loads, in degrees
% 
% OUTPUTS:
% InitTemps_a*_PD*_cv.dyn is written to the CWD
% PointLoads_a*.dyn is written to the CWD
%
% Example:
% makeLoadsTemps('dyna_ispta_att0.5.mat','/emfd/mlp6/field/VF10-5/
% F1p3_foc20mm/dyna_ispta_att0.5.mat',5357,168,4.2,8e-6,'q',1, 0);
%
% Mark 06/15/07
%
% CHANGELOG
% * 2018-01-03: add angle_deg input (mlp6)
%

DEBUG = 0;

if ~exist('angle_deg', 'var'),
    angle_deg = 0;
end

% node tolerance to search for center line in the lateral
% dimension
LatTol = 1e-3;  % cm

% find the Isppa value that Field II solved for in the
% normalization case (limiting the search to the focal zone,
% +/- 25% the focal depth)
AxialSearch = 0.25; % percentage of the focal depth to search
										%for the Isppa value
load(NormName);
NormIntensity = intensity;
mpn = FIELD_PARAMS.measurementPointsandNodes;
NormFocalDepth = FIELD_PARAMS.focus(3)*100;  % convert m -> cm

% check to make sure nodes exist at lat == 0 for the push
if(isempty(find(abs(mpn(:,3)) < LatTol))),
    keyboard
    error('lat = 0 nodes missing for rad force excitation');
end;

[NormAx, NormFZ] = extractAxisIntensity(NormName, 3, [0 0]);

% what is the Isppa value that field has solved
NormFieldIsppa = max(NormFZ)

% make plot of the intensity profile to make sure that
% everything makes sense
if DEBUG,
    figure;
    plot(abs(mpn(NormFZ,4)),NormIntensity(NormFZ),'-kx');
    hold on;
end;

% find normalization max in desired alpha
load(InputName);
InputIntensity = intensity;
mpn = FIELD_PARAMS.measurementPointsandNodes;
FocalDepth = FIELD_PARAMS.focus(3)*100;  % convert m -> cm

[Ax, FZ] = extractAxisIntensity(InputName, 3, [0 0]);

% what is the Isppa value that field has solved
FieldIsppa = max(FZ)

if DEBUG,
    % add this one to the plot
    plot(abs(mpn(FZ,4)),InputIntensity(FZ),'-rx');
    xlabel('Depth (cm)');
    ylabel('Field Intensity');
    title('Comparison of Field Intensity Profiles');
    legend('Normalization','Input','Location','Best');
    legend boxoff;
end;

% normalize InputIntensity
InputIntensity = InputIntensity./FieldIsppa;

% toss intensities below 5% of Isppa
InputIntensity=InputIntensity.*(InputIntensity>=0.05);

% now zero out values near the transducer face b/c they
% violated the farfield assumption in field
z0=find(abs(mpn(:,4)) < 0.001);
InputIntensity(z0)=0;

% the BIG step - scale the Field intensities relative to the
% known intensity value for the normalization data
Field_I_Ratio = FieldIsppa/NormFieldIsppa
ScaledIntensity=InputIntensity*IsppaNorm*Field_I_Ratio;

SoundSpeed = FIELD_PARAMS.soundSpeed*100;  % convert m/s -> cm/s

% open up an ASCII file for writing point loads and initial temperatures
% and add comments telling the user what runtime parameters were used
RunTimeDate = date;

eval(sprintf('fout = fopen(''InitTemps_a%.1f_PD%.1f_cv%.1f.dyn'',''w'');',FIELD_PARAMS.alpha,PulseDuration,cv));
fprintf(fout,'*INITIAL_TEMPERATURE_NODE\n');
fprintf(fout,'$ Generated by makeLoadsTemps on %s\n',RunTimeDate);
fprintf(fout,'$ Normalization File:\n');
fprintf(fout,'$ %s\n',NormName);
fprintf(fout,'$ Normalization Isppa = %.1f W/cm^2\n',IsppaNorm);
fprintf(fout,'$ Pulse Duration = %.1f us\n',PulseDuration);
fprintf(fout,'$ Specific Heat = %.1f W s/cm^3\n',cv);
fprintf(fout,'$ Frequency = %.1f MHz\n',FIELD_PARAMS.Frequency);

%eval(sprintf('foutload = fopen(''PointLoads_a%.1f.dyn'',''w'');',FIELD_PARAMS.alpha));
fout_filename = sprintf('PointLoads-f%.2f-F%.1f-FD%.3f-a%.2f.dyn',FIELD_PARAMS.Frequency,FIELD_PARAMS.Fnum,FIELD_PARAMS.focus(3),FIELD_PARAMS.alpha);
foutload = fopen(fout_filename,'w');
fprintf(foutload,'*LOAD_NODE_POINT\n');
fprintf(foutload,'$ Generated by makeLoadsTemps on %s\n',RunTimeDate);
fprintf(foutload,'$ Normalization File:\n');
fprintf(foutload,'$ %s\n',NormName);
fprintf(foutload,'$ Normalization Isppa = %.1f W/cm^2\n',IsppaNorm);
fprintf(foutload,'$ Frequency = %.1f MHz\n',FIELD_PARAMS.Frequency);
if isa(ElementVolume,'float'),
    fprintf(foutload,'$ Element Volume = %d cm^3\n',ElementVolume);
elseif isa(ElementVolume,'char'),
    fprintf(foutload,'$ Node Volume File: %s\n',ElementVolume);
    NodeVolumes = load(ElementVolume); 
end;


% now solve for initial temperatures and point loads
MaxTemp = 0;
MaxLoad = 0;
for x=1:length(mpn),
    xcoord = mpn(x,2);
    ycoord = mpn(x,3);
    zcoord = mpn(x,4);
    if (ScaledIntensity(x)~=0 & zcoord~=0) 
        if(isnan(ScaledIntensity(x)) || (ScaledIntensity(x) > (10*IsppaNorm))),
            warning('Excessive intensities are being computed; not writing to output file');
        else,
            NodeID=mpn(x,1);
            % convert alpha -> Np/cm
            AlphaNp = FIELD_PARAMS.alpha*FIELD_PARAMS.Frequency/8.616;
            % units are W, cm, s -> deg C
            InitTemp = 2*AlphaNp*ScaledIntensity(x)*PulseDuration*1e-6 / cv;
            if(InitTemp > MaxTemp),
                MaxTemp = InitTemp;
                ScaledIsppa = ScaledIntensity(x);
            end;
            % 1 W = 10,000,000 g cm^2/s^2
            ScaledIntensityLoad = ScaledIntensity(x) * 10000000;
            BodyForce = (2*AlphaNp*ScaledIntensityLoad)/SoundSpeed;
            if isa(ElementVolume,'float'),
                PointLoad = BodyForce * ElementVolume;
            elseif isa(ElementVolume,'char'),
                PointLoad = BodyForce * NodeVolumes(find(NodeVolumes(:,1) == NodeID),2);
            end;
            switch sym,
                case 'q'
                    % if the load is on the symmetry axis (x = y = 0), then divide by 4; if
                    % not, check if it is on a symmetry face (x = 0 || y = 0), then divide
                    % by 2
                    if(abs(xcoord) < 1e-4 && abs(ycoord) < 1e-4),
                        PointLoad = PointLoad / 4;
                    elseif(abs(xcoord) < 1e-4 || abs(ycoord) < 1e-4),
                        PointLoad = PointLoad / 2;
                    end;
                case 'h'
                    % if the load is on the symmetry face (y=0), then divide by 2
                    if(abs(ycoord) < 1e-4),
                        PointLoad = PointLoad / 2;
                    end;
                otherwise
                    disp('No symmetry load scaling performed.')
            end;
            % write the temps to the file to be read into dyna
            fprintf(fout,'%i,%.4f\n',NodeID,InitTemp);
            % write point load data (negative to point in 
            % -z direction in the dyna model)
            if (angle_deg == 0),
                fprintf(foutload,'%d,3,%d,%0.2e,0 \n',NodeID,LCID,-PointLoad);
            else,
                fprintf(foutload,'%d,3,%d,%0.2e,0 \n',NodeID,LCID,-PointLoad*cosd(angle_deg));
                fprintf(foutload,'%d,2,%d,%0.2e,0 \n',NodeID,LCID,PointLoad*sind(angle_deg));
            end

            if(abs(PointLoad) > MaxLoad),
                MaxLoad = abs(PointLoad);
            end;
        end;
    end;
end;

disp(sprintf('Point loads are being oriented in the -z direction.\n'));

disp(sprintf('Isppa = %.1f W/cm^2\n',ScaledIsppa));
disp(sprintf('MaxTemp = %.4f deg C\n',MaxTemp));
disp(sprintf('MaxLoad = %.4f g cm/s^2\n',MaxLoad));

fprintf(fout,'*END');
fprintf(foutload,'*END');
fclose(fout);
fclose(foutload);

disp('The following output files have been written:');
disp(sprintf('InitTemps_a%.1f_PD%.1f_cv%.1f.dyn',FIELD_PARAMS.alpha,PulseDuration,cv));
disp(fout_filename);

disp(sprintf('These can be included in the ls-dyna input decks.\n'));
