function metrics=run_merged_converter(stopTime)
% Run the actual two-power-stage switching model and measure selected output.
root=fileparts(mfilename('fullpath'));
m='BuckBoost_16V_28V_merged';
if nargin<1, stopTime=0.04; end
if ~bdIsLoaded(m), load_system(fullfile(root,[m '.slx'])); end
fprintf('Running merged converter, %.5g s...\n',stopTime);
tic;
si=Simulink.SimulationInput(m);
si=si.setModelParameter('StopTime',num2str(stopTime,16),'ReturnWorkspaceOutputs','on');
% Batch analysis uses logged signals, avoiding Scope graphics overhead.
% This is a temporary override: the saved user model keeps Scope enabled.
si=si.setBlockParameter([m '/Scope'],'Commented','on');
out=sim(si);
elapsed=toc;
signals={'Vload','Iload','Vbuck','Vboost','buck16v_IL','boost28v_IL', ...
    'buck16v_Iout','boost28v_Iout'};
for k=1:numel(signals)
    ts=out.logsout.get(signals{k}).Values;
    data.(signals{k})=ts.Data;
    if k==1, data.t=ts.Time; end
end
metrics=struct;
t=data.t;
pre=t>0.015 & t<0.019;
post=t>0.035 & t<0.039;
metrics.Duration_s=stopTime;
metrics.Run_time_s=elapsed;
metrics.Warning_count=numel(out.SimulationMetadata.ExecutionInfo.WarningDiagnostics);
metrics.Pre_Vload_mean_V=mean(data.Vload(pre));
metrics.Pre_Vbuck_mean_V=mean(data.Vbuck(pre));
metrics.Pre_Vboost_mean_V=mean(data.Vboost(pre));
metrics.Post_Vload_mean_V=mean(data.Vload(post));
metrics.Post_Vbuck_mean_V=mean(data.Vbuck(post));
metrics.Post_Vboost_mean_V=mean(data.Vboost(post));
metrics.Post_Iload_mean_A=mean(data.Iload(post));
metrics.Buck_peak_current_A=max(data.buck16v_IL);
metrics.Boost_peak_current_A=max(data.boost28v_IL);
metrics.Buck_voltage_peak_V=max(data.Vbuck);
metrics.Boost_voltage_peak_V=max(data.Vboost);
gap=t>=0.02 & t<0.02005;
after=t>=0.02005;
metrics.Gap_voltage_min_V=min(data.Vload(gap));
metrics.Post_connection_min_V=min(data.Vload(after));
metrics.Post_connection_max_V=max(data.Vload(after));
metrics.Log_sample_s=mean(diff(t));
metrics.Scope='Closed-loop equivalent stages with energized ICs; not chip macro-models';
bad=find(after & (data.Vload<27.44 | data.Vload>28.56),1,'last');
if isempty(bad)
    metrics.Recovery_after_connection_s=0;
elseif bad<numel(t)
    metrics.Recovery_after_connection_s=t(bad+1)-0.02005;
else
    metrics.Recovery_after_connection_s=NaN;
end
warnings=out.SimulationMetadata.ExecutionInfo.WarningDiagnostics;
save(fullfile(root,'merged_data.mat'),'data','metrics','warnings','-v7.3');
write_merged_csv();
fid=fopen(fullfile(root,'merged_metrics.json'),'w','n','UTF-8');
fprintf(fid,'%s\n',jsonencode(metrics)); fclose(fid);
f=figure('Name','16V to 28V full converter switching','Color','w', ...
    'Position',[70 60 1300 860]);
stride=max(1,floor(numel(t)/100000)); ix=1:stride:numel(t);
subplot(2,2,1); plot(t(ix)*1000,data.Vload(ix)); grid on;
xlabel('Time (ms)'); ylabel('Common output (V)'); title('24 V input remains connected');
subplot(2,2,2); plot(t(ix)*1000,data.Vbuck(ix)); hold on;
plot(t(ix)*1000,data.Vboost(ix)); grid on;
legend('Buck output capacitor','Boost output capacitor','Location','best');
xlabel('Time (ms)'); ylabel('Branch voltage (V)'); title('Both branches regulate independently');
subplot(2,2,3); iz=t>0.0195 & t<0.022;
plot(t(iz)*1000,data.Vload(iz)); grid on;
xlabel('Time (ms)'); ylabel('Common output (V)'); title('50 us break-before-make interval');
subplot(2,2,4); plot(t(ix)*1000,data.Iload(ix)); grid on;
xlabel('Time (ms)'); ylabel('Common load current (A)'); title('Single 14 ohm load');
sgtitle('Full switching power stages with equivalent feedback; energized initial state','FontSize',15);
exportgraphics(f,fullfile(root,'merged_results.png'),'Resolution',160);
exportgraphics(f,fullfile(root,'merged_results.pdf'),'ContentType','vector');
fprintf('%s\n',jsonencode(metrics));
fprintf('Warnings: %d\n',numel(warnings));
for k=1:numel(warnings), disp(warnings(k)); end
end
