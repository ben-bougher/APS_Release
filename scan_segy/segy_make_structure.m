function segy_make_structure(segyfile,il_byte,xl_byte,offset_byte, block_size)  
%% ------------------ FUNCTION DEFINITION ---------------------------------
%   Makes _mat_lite and mat_orig_lite files from the Seismic Header 
%   Run this on one angle stack as they should all have the same
%   geometry/file structure. This will create a mat file in the location of the input SEGY definining the
%   structure of the input file.Structure format:
%   PKey SKey Byte_Loc SKey_max SKey_inc TKey TKey_max TKey_inc
%   Use segy_index_checker(seismic_mat_path) to check scan validity
%   
%   Arguments:  
%       segyfile = full path to the segy file
%       il_byte = inline byte location
%       xl_byte = Cross Line byte Location in the SEGY header
%       offset_byte =  Offset Byte Location in the SEGY header
%       block_size =  Number of traces per data block    
%
%   Note: Typical IL/XL byte locations: 189 & 193.
%   Offset byte location is typically 37 
%
%   Outputs:
%       .mat file = metadata including sample rate, n_samples etc.
%       .mat_lite file = binary file containing IL/XL byte locations.
%
%   Writes to Disk:
%       job meta files: give description and paths

%%

  % Seismic Header
  seismic = seismic_header_init(segyfile);
      
  % Summarize the byte locations of each trace
  matlite_header_init(seismic, il_byte, xl_byte, ...
                      block_size);

   
end





