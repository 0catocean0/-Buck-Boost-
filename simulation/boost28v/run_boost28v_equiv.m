function metrics = run_boost28v_equiv()
% Run the pre-energized-input case and export actual switching-model results.
rootDir = fileparts(mfilename('fullpath'));
model = 'Boost_24V_28V_equiv_v1';
modelFile = fullfile(rootDir,[model '.slx']);
if ~isfile(modelFile), build_boost28v_equiv(); end
if ~bdIsLoaded(model), load_system(modelFile); end
fprintf('Running 20 ms switching simulation...\n');
tic;
result = sim(model,'StopTime','0.02','ReturnWorkspaceOutputs','on');
elapsed = toc;
mw = get_param(model,'ModelWorkspace');
names = {'Vin','L','RL','C','ESR','Rload','Ron','Rdiode','Vf', ...
    'fsw','pwmSteps','Ts','D','softStart','pwmStart','Vc0','IL0'};
for k=1:numel(names), p.(names{k})=getVariable(mw,['p_' names{k}]); end
t = result.vout_log.Time;
vout = result.vout_log.Data;
iout = result.iout_log.Data;
iL = result.iin_log.Data;
vsw = result.vsw_log.Data;
duty = result.duty_log.Data;
gate = result.gate_log.Data;
nWin = 100*p.pwmSteps;
idx = (numel(t)-nWin):(numel(t)-1);
metrics = struct;
metrics.Vout_mean_V = mean(vout(idx));
metrics.Iout_mean_A = mean(iout(idx));
metrics.IL_mean_A = mean(iL(idx));
metrics.Vout_ripple_pp_mV = 1000*(max(vout(idx))-min(vout(idx)));
metrics.IL_ripple_pp_A = max(iL(idx))-min(iL(idx));
metrics.Voltage_error_percent = 100*(metrics.Vout_mean_V/28-1);
metrics.Pout_W = mean(vout(idx).*iout(idx));
metrics.Pin_W = p.Vin*mean(iL(idx));
metrics.Partial_loss_model_efficiency_percent = 100*metrics.Pout_W/metrics.Pin_W;
metrics.Vout_peak_V = max(vout);
metrics.IL_peak_A = max(iL);
metrics.Vsw_peak_V = max(vsw);
metrics.Gate_duty_measured = mean(double(gate(idx)));
metrics.Window_cycles = 100;
metrics.Window_start_s = t(idx(1));
metrics.Window_end_s = t(idx(end));
metrics.Step_s = p.Ts;
metrics.Run_time_s = elapsed;
metrics.Sample_count = numel(t);
bad=find(vout<28*0.98 | vout>28*1.02,1,'last');
if isempty(bad)
    metrics.Entry_into_2percent_band_s=0;
elseif bad<numel(t)
    metrics.Entry_into_2percent_band_s=t(bad+1);
else
    metrics.Entry_into_2percent_band_s=NaN;
end
metrics.Model_scope = 'Open-loop SPS switching power-stage equivalent; not TPS55340';
metrics.Initial_condition = 'Precharged capacitor with input already connected';
metrics.Ripple_limit_note = '100 mVpp is a provisional interpretation, not confirmed wording';
warnings = result.SimulationMetadata.ExecutionInfo.WarningDiagnostics;
save(fullfile(rootDir,'boost28v_main_data.mat'), ...
    't','vout','iout','iL','vsw','duty','gate','p','metrics','warnings','-v7');
fid=fopen(fullfile(rootDir,'boost28v_metrics.json'),'w','n','UTF-8');
fprintf(fid,'%s\n',jsonencode(metrics)); fclose(fid);
writetable(table(t(idx),vout(idx),iout(idx),iL(idx),vsw(idx), ...
    double(gate(idx)),'VariableNames', ...
    {'Time_s','Vout_V','Iout_A','IL_A','Vsw_V','Gate'}), ...
    fullfile(rootDir,'boost28v_steady_100cycles.csv'));

plot_boost28v_results();
fprintf('%s\n',jsonencode(metrics));
fprintf('Simulation warnings: %d\n',numel(warnings));
for k=1:numel(warnings), disp(warnings(k)); end
fprintf('Results saved in %s\n',rootDir);
end
