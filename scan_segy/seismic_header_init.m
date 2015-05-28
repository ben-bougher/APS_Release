function [seismic] = seismic_header_init(segyfile, il_byte, xl_byte)
% $$$ Creates a structure summarizing a segy file.
% $$$ 
% $$$ Arguments:
% $$$   segyfile - path to the .segy file
% $$$   
% $$$ Returns a seismic header structure
% $$$ 
% $$$ Fields:
% $$$   filepath: Path to the segy file
% $$$   fid: Unique file id descriptor (fopen)
% $$$   text_header: Ascii header from the segy file
% $$$   binary_header: Binary header from the segy file
% $$$   n_samples: Number of samples per trace
% $$$   s_rate: Sample rate of the data [hz]
% $$$   file_type: (1:5) integer specifying the type of segy file
% $$$   ilxl_bytes: [il xl] The byte positions of the il and crossline
% $$$       description for each trace
% $$$   n_traces: Number of traces in the segy file
%%
    
    % Create a structure seismic for the segy file header information
    seismic = {};

    % Read input file
    seismic.filepath = segyfile;     

    % Find and store file ID after opening in Big-endian ordering
    seismic.fid = fopen(seismic.filepath,'r','b');               
    
    % Read the seismic EBCDIC HEADER first 3200 characters
    seismic.text_header = fread(seismic.fid,3200,'uchar');  

    % Reshape the string of 3200 characters into a 80 x 40 matrix and
    % convert to ASCII
    seismic.text_header = char(ebcdic2ascii(reshape(seismic.text_header,80,40)')); 
    
    % Read binary header (400 bytes)
    seismic.binary_header = fread(seismic.fid,400,'uint8'); 

    % Re-interpret binary header as uint16 or uint32 as required
    two_bytes = seismic.binary_header(1:2:399)*256 + seismic.binary_header(2:2:400);
    four_bytes = ((seismic.binary_header(1:4:9)*256 + ...
                   seismic.binary_header(2:4:10))*256+ ...
                  seismic.binary_header(3:4:11))*256+seismic.binary_header(4:4:12);
    seismic.binary_header = [four_bytes(1:3);two_bytes(7:200)];

  
    %-------------------------------------------------------------------
    %-----WRITE SOME MORE INFORMATION IN THE STUCTURE FROM HEADERS------------
    seismic.n_samples = seismic.binary_header(8);             
    seismic.s_rate = seismic.binary_header(6);                 
    seismic.file_type = seismic.binary_header(10);            
    
    
    % need to break if not 1 or 5 because we don't handle it
    if seismic.file_type < 1 || seismic.file_type > 5 
        msgID = 'segy_make_structure:BadFileType';
        msg = 'segy file type must be between 1 and 5';
        baseException = MException(msgID,msg);
        throw(baseException);
    else
        bytes_per_sample = 4;  % Assign default 4 bytes per sample
    end
    
    seismic.bytes_per_sample = bytes_per_sample;
    
    % store the inline and crossline byte locations
    seismic.ilxl_bytes = [il_byte xl_byte];                     
    ll = dir(seismic.filepath);

    % Number of traces = (file size - header size)/ 
    %                    (size of each trace+size of trace header)
    seismic.n_traces = (1/bytes_per_sample)*(ll.bytes-3600)/ ...
        (seismic.n_samples+60); 
end


function ascii=ebcdic2ascii(ebcdic)
% Function converts EBCDIC string to ASCII
% see http://www.room42.com/store/computer_center/code_tables.shtml
%
% Written by: E. Rietsch: Feb. 20, 2000
% Last updated:
%
%           ascii=ebcdic2ascii(ebcdic)
% INPUT
% ebcdic    EBCDIC string
% OUTPUT
% ascii	   ASCII string

    pointer= ...
        [ 0    16    32    46    32    38    45    46    46    46    46    46   123   125    92    48
          1    17    33    46    46    46    47    46    97   106   126    46    65    74    46    49
          2    18    34    50    46    46    46    46    98   107   115    46    66    75    83    50
          3    19    35    51    46    46    46    46    99   108   116    46    67    76    84    51
          4    20    36    52    46    46    46    46   100   109   117    46    68    77    85    52
          5    21    37    53    46    46    46    46   101   110   118    46    69    78    86    53
          6    22    38    54    46    46    46    46   102   111   119    46    70    79    87    54
          7    23    39    55    46    46    46    46   103   112   120    46    71    80    88    55
          8    24    40    56    46    46    46    46   104   113   121    46    72    81    89    56
          9    25    41    57    46    46    46    46   105   114   122    46    73    82    90    57
          10    26    42    58    46    33   124    58    46    46    46    46    46    46    46    46
          11    27    43    59    46    36    44    35    46    46    46    46    46    46    46    46
          12    28    44    60    60    42    37    64    46    46    46    46    46    46    46    46
          13    29    45    61    40    41    95    39    46    46    91    93    46    46    46    46
          14    30    46    46    43    59    62    61    46    46    46    46    46    46    46    46
          15    31    47    63   124    94    63    34    46    46    46    46    46    46    46    46];

    pointer=reshape(pointer,1,256);

    ascii=pointer(ebcdic+1);

end
