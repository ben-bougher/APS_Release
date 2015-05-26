function matlite = matlite_header_init(seismic, block_size, offset_byte)
%% Function definition
  %  Makes a matlite file that summarizes the byte locations for each trace.
  %  Arguments:
  %     Seismic header
  %  
  %  Fields in matlite file:
  %%

  il_byte = str2num(seismic.ilxl_bytes(1:3));
  xl_byte = str2num(seismic.ilxl_bytes(4:6));
   
  bytes_per_sample = seismic.bytes_per_sample;
  
  % Break up file into path and extentions
  [filepath, filename, ext] = fileparts(seismic.filepath);
  matfile_lite = strcat(filepath,'/', filename, '.mat_lite');

  % Convert File path into 64-bit integer array
  filepath_binary = uint64(seismic.filepath);  

  % Padding for file path by zeros at the end to make its length 2000
  pad_filepath = zeros(1,(2000-length(filepath_binary)));  
  filepath_binary = [filepath_binary,pad_filepath];

  % write basic information into .mat_orig_lite file
  fid_write = fopen(matfile_lite,'w');                           
  fwrite(fid_write,[filepath_binary';seismic.file_type;seismic.s_rate;...
                    seismic.n_samples;seismic.n_traces;il_byte;xl_byte;...
                    offset_byte],'double'); 

  skip_textual_binary = 3600; % Length of EBCIDIC header (bytes)
  trc_head = 240;             % Length of Trace Header (bytes)
  trc_length = seismic.n_samples*bytes_per_sample; % Length of trace (bytes)
  last_byte = 0;

  
  % Set number of traces per block
  blocktr = block_size;       
  if seismic.n_traces < blocktr
    blocktr = seismic.n_traces;
  end
  loop_end = floor(seismic.n_traces/blocktr);    

  % Loop to read segy data 
  for ii = 1:loop_end
      
      % Read blocktr x trace headers and trace data as uint32 into a 
      % temporary matrix
      tmptr = fread(seismic.fid,...
                    [120+(bytes_per_sample/2)*seismic.n_samples,blocktr],...
                    'uint16=>uint16');
      tmptr = tmptr(1:120,:);
      
      % extract the header and byte mapping
      [trace_header bytes_to_samples] = interpret(tmptr);
      
      % primary key
      trace_ilxl_bytes(:,1) = trace_header(bytes_to_samples == ...
                                           il_byte,:)';
      % secondary key
      trace_ilxl_bytes(:,2) = trace_header(bytes_to_samples == ...
                                           xl_byte,:)';
      % byte location of start of block
      trace_ilxl_bytes(:,3) = last_byte+(trc_head:trc_head+...
                                         trc_length:blocktr* ...
                                         (trc_length+trc_head));
      
      % store to add on during loop
      last_byte = trace_ilxl_bytes(end,3)+trc_length;
      trace_ilxl_bytes(:,3) = trace_ilxl_bytes(:,3)+skip_textual_binary;
      
      % TODO Check for gathers
      n_traces_to_check = 1000;
      if n_traces_to_check > blocktr
          n_traces_to_check = blocktr;
      end
      
      
      % Compress redundant information from keys
      % test to see if there are any duplicate inline/xline locations in
      % the first 1000 traces. Determines pre or post stack data
      % TODO This should be an input parameter
      if length(unique(trace_ilxl_bytes(1:n_traces_to_check,1:2),'rows')) < n_traces_to_check
          % is gathers
          is_gather = 1;
          if ii == 1
              fwrite(fid_write,is_gather,'double');
          end
          
          % tertiary key
          trace_ilxl_bytes(:,4) = trace_header(bytes_to_samples == ...
                                               offset_byte,:)'; 
          
          compress_ilxl_bytes = ...
              gather_compress_ilxl_bytes_offset(trace_ilxl_bytes,blocktr);
          
      else
          is_gather = 0;
          if ii == 1
              fwrite(fid_write,is_gather,'double');
          end
          
          compress_ilxl_bytes = trace_compress_ilxl_bytes(trace_ilxl_bytes,blocktr);
      end
      
      fwrite(fid_write,reshape(compress_ilxl_bytes',[],1),'double');
      usefix = 0;
      % fprintf('Block %d completed...\n',ii);
  end

  % Calculate the number of trace headers not read by the loop above
  leftovers = seismic.n_traces-loop_end*blocktr;

  % Read the remaining trace headers (if any)
  clearvars tmptrheader trace_header bytes_to_samples trace_ilxl_bytes
  if leftovers > 0
      tmptr = fread(seismic.fid,[120+2*seismic.n_samples,leftovers],'uint16=>uint16');
      tmptr = tmptr(1:120,:);
      [trace_header, bytes_to_samples] = interpret(tmptr);
      
      trace_ilxl_bytes(:,1) = trace_header(bytes_to_samples == il_byte,:)';
      trace_ilxl_bytes(:,2) = trace_header(bytes_to_samples == xl_byte,:)';
      trace_ilxl_bytes(:,3) = last_byte+(trc_head:trc_head+trc_length:leftovers*(trc_length+trc_head));
      trace_ilxl_bytes(:,3) = trace_ilxl_bytes(:,3)+skip_textual_binary;
      
      
      % Check for gathers
      if is_gather == 1;
          % is gathers
          trace_ilxl_bytes(:,4) = trace_header(bytes_to_samples == offset_byte,:)'; % offset hard wired
          compress_ilxl_bytes = gather_compress_ilxl_bytes_offset(trace_ilxl_bytes,leftovers);
       
      else
          compress_ilxl_bytes = trace_compress_ilxl_bytes(trace_ilxl_bytes,leftovers);
      end
      
      fwrite(fid_write,reshape(compress_ilxl_bytes',[],1),'double');
      usefix = 0;
  end

  % Close segy file

  fclose('all');
  clearvars tmptrheader trace_header bytes_to_samples trace_ilxl_bytes
end

function [trace_header bytes_to_samples] = interpret(tmptrheader)
    byte_type = [ ...
        2*ones(7,1); ones(4,1);
        2*ones(8,1); ones(2,1);
        2*ones(4,1); ones(46,1);
        2*ones(5,1); ones(2,1);
        2*ones(1,1); ones(5,1);
        2*ones(1,1); ones(1,1);
        2*ones(1,1); ones(2,1);
        2*ones(1,1); 2*ones(1,1)];

    ntr = size(tmptrheader,2);
    trace_header = zeros(91,ntr);
    bytes_to_samples = zeros(91,1);

    count =1;
    for ii = 1:91
        bytes_to_samples(ii,1) = 2*count-1;
        if byte_type(ii) == 1
            trace_header(ii,:) = double(tmptrheader(count,:));
            count = count+1;
        elseif byte_type(ii) == 2
            trace_header(ii,:) = double(tmptrheader(count,:))*2^16 + double(tmptrheader(count+1,:));
            count = count+2;
        end
    end

    trace_header(21,:) = trace_header(21,:)-2^16;

end

