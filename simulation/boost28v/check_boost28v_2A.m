function capacity = check_boost28v_2A()
% Slightly heavier than 14 ohm to verify current >= 2 A despite voltage error.
rootDir=fileparts(mfilename('fullpath'));
model='Boost_24V_28V_equiv_v1';
if ~bdIsLoaded(model), load_system(fullfile(rootDir,[model '.slx'])); end
base=load(fullfile(rootDir,'boost28v_main_data.mat'),'p','metrics');
p=base.p;
si=Simulink.SimulationInput(model);
si=si.setVariable('p_Rload',13.9,'Workspace',model);
si=si.setVariable('p_pwmStart',-p.softStart,'Workspace',model);
si=si.setVariable('p_Vc0',base.metrics.Vout_mean_V,'Workspace',model);
si=si.setVariable('p_IL0',base.metrics.IL_mean_A*14/13.9,'Workspace',model);
si=si.setModelParameter('StopTime','0.003','ReturnWorkspaceOutputs','on');
result=sim(si);
nWin=100*p.pwmSteps;
idx=(numel(result.vout_log.Time)-nWin):(numel(result.vout_log.Time)-1);
v=result.vout_log.Data(idx); i=result.iout_log.Data(idx);
capacity.Load_ohm=13.9;
capacity.Vout_mean_V=mean(v);
capacity.Iout_mean_A=mean(i);
capacity.Vout_ripple_pp_mV=1000*(max(v)-min(v));
capacity.Warnings=numel(result.SimulationMetadata.ExecutionInfo.WarningDiagnostics);
capacity.Passes_2A_point=capacity.Iout_mean_A>=2 ...
    && capacity.Vout_mean_V>=27.44 && capacity.Vout_mean_V<=28.56;
save(fullfile(rootDir,'boost28v_2A_check.mat'),'capacity','v','i','p');
fid=fopen(fullfile(rootDir,'boost28v_2A_check.json'),'w','n','UTF-8');
fprintf(fid,'%s\n',jsonencode(capacity)); fclose(fid);
assert(capacity.Passes_2A_point,'Boost28:Capacity','The >=2 A operating point failed.');
fprintf('%s\n',jsonencode(capacity));
end
