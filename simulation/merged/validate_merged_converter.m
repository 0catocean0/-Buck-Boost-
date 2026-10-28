function validation=validate_merged_converter()
% Verify working-point regulation and sensitivity to electrical solver step.
root=fileparts(mfilename('fullpath'));
m='BuckBoost_16V_28V_merged';
q=load(fullfile(root,'merged_data.mat'),'data','metrics');
d=q.data; t=d.t;
pre=t>0.015 & t<0.019;
post=t>0.035 & t<0.039;
validation.Buck_selected_mean_V=mean(d.Vbuck(pre));
validation.Buck_unselected_mean_V=mean(d.Vbuck(post));
validation.Boost_unselected_mean_V=mean(d.Vboost(pre));
validation.Boost_selected_mean_V=mean(d.Vboost(post));
validation.Selected_16V_pp_mV=1000*(max(d.Vload(pre))-min(d.Vload(pre)));
validation.Selected_28V_pp_mV=1000*(max(d.Vload(post))-min(d.Vload(post)));
validation.Load_14ohm_max_error_A=max(abs(d.Iload-d.Vload/14));
validation.Pre_voltage_in_band=all(d.Vload(pre)>15.68 & d.Vload(pre)<16.32);
validation.Post_voltage_in_band=all(d.Vload(post)>27.44 & d.Vload(post)<28.56);
validation.Buck_idle_in_band=all(d.Vbuck(post)>15.68 & d.Vbuck(post)<16.32);
validation.Boost_idle_in_band=all(d.Vboost(pre)>27.44 & d.Vboost(pre)<28.56);
gap=t>0.020005 & t<0.020045;
validation.Gap_max_V=max(abs(d.Vload(gap)));
validation.Break_before_make_verified=validation.Gap_max_V<0.01;
validation.Runtime_warnings=q.metrics.Warning_count;
assert(validation.Pre_voltage_in_band && validation.Post_voltage_in_band, ...
    'Merged:Voltage','Selected output does not meet the voltage bands.');
assert(validation.Buck_idle_in_band && validation.Boost_idle_in_band, ...
    'Merged:Idle','An unselected branch does not regulate.');
assert(validation.Load_14ohm_max_error_A<1e-6 && validation.Break_before_make_verified, ...
    'Merged:Connection','Load identity or switch dead-time check failed.');

% Preserve digital control clock; halve only electrical solver step.
if ~bdIsLoaded(m), load_system(fullfile(root,[m '.slx'])); end
fprintf('Electrical half-step check, two short 8 ms runs...\n');
a=short_run(false);
b=short_run(true);
validation.Short_base_mean_V=a.mean;
validation.Short_fine_mean_V=b.mean;
validation.Short_base_pp_mV=a.pp;
validation.Short_fine_pp_mV=b.pp;
validation.Short_mean_difference_V=b.mean-a.mean;
validation.Short_pp_difference_percent=100*(b.pp/a.pp-1);
validation.Electrical_step_check_pass=abs(b.mean-a.mean)<0.02 && abs(b.pp/a.pp-1)<0.1;
validation.Step_check_warnings=a.warnings+b.warnings;
assert(validation.Electrical_step_check_pass,'Merged:Step','Electrical step sensitivity is too high.');
fid=fopen(fullfile(root,'merged_validation.json'),'w','n','UTF-8');
fprintf(fid,'%s\n',jsonencode(validation)); fclose(fid);
fprintf('%s\n',jsonencode(validation));
    function s=short_run(fine)
        si=Simulink.SimulationInput(m);
        si=si.setVariable('p_tOpen',0.001,'Workspace',m);
        si=si.setVariable('p_tClose',0.00105,'Workspace',m);
        si=si.setModelParameter('StopTime','0.008','ReturnWorkspaceOutputs','on');
        si=si.setBlockParameter([m '/Scope'],'Commented','on');
        if fine
            si=si.setModelParameter('FixedStep','p_Ts/2');
            si=si.setBlockParameter([m '/powergui'],'SampleTime','p_Ts/2');
        end
        result=sim(si);
        raw=result.logsout.get('Vload').Values;
        k=raw.Time>0.006 & raw.Time<0.008;
        s.mean=mean(raw.Data(k)); s.pp=1000*(max(raw.Data(k))-min(raw.Data(k)));
        s.warnings=numel(result.SimulationMetadata.ExecutionInfo.WarningDiagnostics);
    end
end
