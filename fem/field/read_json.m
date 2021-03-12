function [jsonstruct] = read_json(jsonfile)
% function [jsonstruct] = read_json(jsonfile)
%
% PARAMS:
%   jsonfile (str) - JSON file
%
% RETURNS:
%   jsonstruct - structure of JSON key:value pairs
%

fid = fopen(jsonfile);
rawtext = fread(fid, '*char');
fclose(fid);

if size(rawtext,1)>size(rawtext,2)
    rawtext= rawtext';
end
jsonstruct = jsondecode(rawtext);
