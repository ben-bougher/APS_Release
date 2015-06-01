function [] = angle_stks_from_gath(job_meta_path,i_block,startvol,volinc,endvol,angwidth,tottracerun)
%% ------------------ FUNCTION DEFINITION ---------------------------------
%% Parameters
% would normaly convert all parameters to double, but keep i_block as string as being passed to
% other modules; it does happen at the bottom of this program for output
%i_block = str2double(i_block);
%
% angle trace data ranges to use, vol is an angle trace either as a
% seperate angle volume or as a angle trace in an angle gather
% number of the first angle trace/volume to read
%%    
    
startvol = str2double(startvol);
% angle trace/volume increment
volinc = str2double(volinc);
% number of the last angle trace/volume to read
%endvol = job_meta.nvols;
endvol = str2double(endvol);
angwidth = str2double(angwidth);

% number of traces to run, put to zero to make it run all traces in the
% block, this is the default, this is also used to pass an inline (pkey
% number to use in testing has to be ilnnnn format
useselectemode = 0;

origstart_vol = startvol;
orig_endvol = endvol;
ebdichdr = ['segy io'];

if isempty(regexp(tottracerun,'il','once')) == 0
    useselectemode = 1;
    requiredinline =  str2double(regexprep(tottracerun,'il',''));

    tottracerun = 0;
else
    tottracerun = str2double(tottracerun);
end
% tottracerun = 500;

% to reduce printout in compilied version turned all warning off
warning off all;

% end of parameters
%#####################################################################
%
% total number of volumes to load
totalvol = length(startvol:volinc:endvol);
droptraces = 1;

%
% Load job meta information 
job_meta = load(job_meta_path);

% add the history of jobs run and this one to the curent ebcdic
if isfield(job_meta,'comm_history')
    ebdichdr2 = job_meta.comm_history;
    tmpebc = ebdichdr2{size(ebdichdr2,1),2};
else
    ebdichdr2{1,2} = '';
    tmpebc = '';
end

for ebcii = (size(ebdichdr2,1)-1):-1:1
    tmpebcc = regexp(ebdichdr2{ebcii,2},'/','split');
    tmpebc = [tmpebc tmpebcc{1}  tmpebcc{end}]; 
end
tmpebc = sprintf('%-3200.3200s',tmpebc);
clear tmpebcc ebdichdr2;


% read all the data for this block
% node_segy_read(job_meta_path,vol_index,i_block)

[~, vol_traces, ilxl_read, offset_read] = node_segy_read(job_meta_path,'1',i_block);

% find the total number of offsets
offset = unique(offset_read);


if droptraces == 1
    
    % % reshape the gather array to the same 3d matrix as the angle volumes and
    % drop as required
    nsamps = size(vol_traces,1);
    fold = length(offset);
    vol_traces = reshape(vol_traces,nsamps,fold,[]);
    
    % grab the actual angles from the gather to pick the correct indicies
    startvol = find(offset == startvol,1);
    endvol = find(offset == endvol,1);
    
    % resize the ilxl data
    tmp_ilxlrd = ilxl_read(1:length(offset):end,:);
    ilxl_read = tmp_ilxlrd;
    clear tmp_ilxlrd;
    
    
    % now loop round making however many angle gathers are requested
    aidx = 1;
    for kk = startvol:angwidth:endvol
        % resize the traces data
        vol_tracestmp = vol_traces(:,(kk:volinc:(kk+(angwidth-volinc))),:);
        kdsb = zeros(size(vol_tracestmp,1),size(vol_tracestmp,3));
        for ii = 1:size(vol_tracestmp,3)
            kds = vol_tracestmp(:,:,ii);
            kdsb(:,ii) = sum((kds ~= 0),2);
        end
        % sum the gather and divide by live samples
        %make logical of what is not zero and cumlatively sum it to get the fold
        
        angle_stk{aidx} = squeeze(sum(vol_tracestmp,2)) ./ kdsb;
        angle_stk{aidx}(isnan(angle_stk{aidx})) = 0;
        %figure(3); imagesc(angle_stk{aidx});  colormap(gray);
        aidx = aidx +1;
        clear kdsb
    end
end

i_block = str2double(i_block);

%% Save results
aidx = 1;
for kk = origstart_vol:angwidth:orig_endvol
    
    
    resultno = 1;
    % Save outputs into correct structure to be written to SEGY.
    results_out{resultno,1} = 'Meta data for output files';
    results_out{resultno,2}{1,1} = ilxl_read;
    results_out{resultno,3} = 'is_gather'; % 1 is yes, 0 is no
    results_out{resultno,2}{2,1} = uint32(zeros(size(angle_stk{aidx},2),1));
    %was written as uint32(zeros(ntraces,1));
    %results_out{resultno,2}{2,1} = offset_read';
     
    ebcstrtowrite = sprintf('%-3200.3200s',[results_out{resultno,1} '  ' ebdichdr '  ' tmpebc]);
    results_out{resultno,1} = ebcstrtowrite;
    
    resultno = resultno + 1;
    
    % correct file names added by SRW - 02/07/14
    

        testdiscpt = ['angle_stk_range_',num2str(kk),'_',num2str((kk+(angwidth-volinc)))];

    results_out{resultno,1} = strcat(testdiscpt);
    %results_out{2,2} = digi_intercept;
    results_out{resultno,2} = angle_stk{aidx};
    results_out{resultno,3} = 0;
    aidx = aidx +1;
    
    % check segy write functions - many different versions now!
    if exist(strcat(job_meta.output_dir,'bg_angle_stks/'),'dir') == 0
        output_dir = strcat(job_meta.output_dir,'bg_angle_stks/');
        mkdir(output_dir);
    else
        output_dir = strcat(job_meta.output_dir,'bg_angle_stks/');
    end
    
    
    node_segy_write(results_out,i_block,job_meta.s_rate/1000,output_dir)
    
end

end


