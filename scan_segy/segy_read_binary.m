function seismic = segy_read_binary(seismic_mat_path)
%% ------------------ FUNCTION DEFINITION ---------------------------------
% segy_read_binary: function to output information in a structured format 
% from meta data .mat_org_lite file 
%   Arguments:
%       seismic_mat_path = path to .mat_org_lite file
%
%   Outputs:
%       seismic = structure containing seismic header information
%
%   Writes to Disk:
%       nothing

%%
%----------INTIALIZING INDICES------------------
filepath_length = 2000;
file_type_length = filepath_length+1;
s_rate_length = file_type_length+1;
n_samples_length = s_rate_length+1;
n_traces_length = n_samples_length+1; 
pkey_length = n_traces_length+1;
skey_length = pkey_length+1;
tkey_length = skey_length+1;
is_gather_length = tkey_length+1;
traces_length = is_gather_length+1;

fid = fopen(seismic_mat_path,'r');                          % Open .mat_orig_lite File for reading
message = ferror(fid); 
tmp_seismic = fread(fid,'double');                          % Read the oppened file

%------------------CREATING THE STRUCTURE TO OUTPUT-------------------
seismic.filepath = char(tmp_seismic(1:filepath_length,1)'); % File Path
seismic.file_type = tmp_seismic(file_type_length,1);        % File Type
seismic.s_rate = tmp_seismic(s_rate_length,1);              % Sample Rate
seismic.n_samples = tmp_seismic(n_samples_length,1);        % Number of samples in a trace?
seismic.n_traces = tmp_seismic(n_traces_length,1);          % Number of traces
seismic.pkey = tmp_seismic(pkey_length,1);                  % Inline Byte?
seismic.skey = tmp_seismic(skey_length,1);                  % x-Line Byte?
seismic.tkey = tmp_seismic(tkey_length,1);                  % Offset Byte?

seismic.is_gather = tmp_seismic(is_gather_length,1);        % Whether Seismic is gather or not

%--?--
% Columns...
if seismic.is_gather == 1 % angle gathers
    seismic.trace_ilxl_bytes = reshape(tmp_seismic(traces_length:end),8,[])';
elseif seismic.is_gather == 0 % angle stacks
    seismic.trace_ilxl_bytes = reshape(tmp_seismic(traces_length:end),5,[])';
else

end
%---------------------------------------------------------------------

fclose(fid);                                                % Close File
end