function checks = validate_boost28v_equiv()
% Numerical time-step check and independent zero-energy cold-start check.
rootDir=fileparts(mfilename('fullpath'));
model='Boost_24V_28V_equiv_v1';
if ~bdIsLoaded(model), load_system(fullfile(rootDir,[model '.slx'])); end
base=load(fullfile(rootDir,'boost28v_main_data.mat'),'p','metrics');
p=base.p;

fprintf('Checking half step with the same frequency and duty...\n');
si=Simulink.SimulationInput(model);
si=si.setVariable('p_Ts',p.Ts/2,'Workspace',model);
si=si.setVariable('p_pwmSteps',2*p.pwmSteps,'Workspace',model);
si=si.setVariable('p_pwmStart',-p.softStart,'Workspace',model);
si=si.setVariable('p_Vc0',base.metrics.Vout_mean_V,'Workspace',model);
si=si.setVariable('p_IL0',base.metrics.IL_mean_A,'Workspace',model);
si=si.setModelParameter('StopTime','0.003','ReturnWorkspaceOutputs','on');
fine=sim(si);
nWin=100*2*p.pwmSteps;
idx=(numel(fine.vout_log.Time)-nWin):(numel(fine.vout_log.Time)-1);
vf=fine.vout_log.Data(idx);
checks.half_step_Vout_mean_V=mean(vf);
checks.half_step_Vout_ripple_pp_mV=1000*(max(vf)-min(vf));
checks.half_step_duty=mean(double(fine.gate_log.Data(idx)));
checks.mean_voltage_difference_V=checks.half_step_Vout_mean_V-base.metrics.Vout_mean_V;
checks.ripple_difference_percent=100*(checks.half_step_Vout_ripple_pp_mV/base.metrics.Vout_ripple_pp_mV-1);
checks.half_step_s=p.Ts/2;
checks.step_convergence_pass=abs(checks.mean_voltage_difference_V)<0.01 ...
    && abs(checks.ripple_difference_percent)<5;
checks.half_step_warning_count=numel(fine.SimulationMetadata.ExecutionInfo.WarningDiagnostics);

fprintf('Checking cold start from zero capacitor voltage and inductor current...\n');
si=Simulink.SimulationInput(model);
si=si.setVariable('p_Vc0',0,'Workspace',model);
si=si.setVariable('p_IL0',0,'Workspace',model);
si=si.setModelParameter('StopTime','0.012','ReturnWorkspaceOutputs','on');
cold=sim(si);
tc=cold.vout_log.Time;
vc=cold.vout_log.Data;
ic=cold.iin_log.Data;
sc=cold.vsw_log.Data;
checks.cold_start_Vout_peak_V=max(vc);
checks.cold_start_IL_peak_A=max(ic);
checks.cold_start_Vsw_peak_V=max(sc);
checks.cold_start_warning_count=numel(cold.SimulationMetadata.ExecutionInfo.WarningDiagnostics);
checks.cold_start_note='Input step into an uncharged output capacitor. PWM soft-start cannot block the passive L-diode charging path.';
save(fullfile(rootDir,'boost28v_coldstart_data.mat'),'tc','vc','ic','sc','p','checks','-v7');
fid=fopen(fullfile(rootDir,'boost28v_validation.json'),'w','n','UTF-8');
fprintf(fid,'%s\n',jsonencode(checks)); fclose(fid);
f=figure('Name','Boost cold-start diagnostic','Color','w','Position',[140 100 1100 700]);
subplot(2,2,1); plot(tc*1e3,vc,'LineWidth',1); grid on;
yline(28,'--'); xlabel('Time (ms)'); ylabel('Output voltage (V)'); title('Cold start: capacitor initially 0 V');
subplot(2,2,2); plot(tc*1e3,ic,'LineWidth',1); grid on;
xlabel('Time (ms)'); ylabel('Inductor current (A)'); title('Passive charging inrush');
subplot(2,2,3); plot(tc*1e6,vc,'LineWidth',1); grid on; xlim([0 600]);
xlabel('Time (us)'); ylabel('Output voltage (V)'); title('First 600 us, PWM still off');
subplot(2,2,4); plot(tc*1e6,ic,'LineWidth',1); grid on; xlim([0 600]);
xlabel('Time (us)'); ylabel('Inductor current (A)'); title('First 600 us, PWM still off');
sgtitle('Diagnostic only: source impedance and inrush protection are not modelled');
exportgraphics(f,fullfile(rootDir,'boost28v_coldstart.png'),'Resolution',170);
exportgraphics(f,fullfile(rootDir,'boost28v_coldstart.pdf'),'ContentType','vector');
assert(checks.step_convergence_pass,'Boost28:TimeStep','Time-step convergence check did not pass.');
fprintf('%s\n',jsonencode(checks));
check_boost28v_2A();
end
