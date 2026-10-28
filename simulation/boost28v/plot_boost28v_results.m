function plot_boost28v_results()
% Regenerate report figures from saved data without repeating simulation.
rootDir=fileparts(mfilename('fullpath'));
q=load(fullfile(rootDir,'boost28v_main_data.mat'));
t=q.t; vout=q.vout; iL=q.iL; iout=q.iout; p=q.p; metrics=q.metrics;
f=figure('Name','28V Boost - measured equivalent-model results', ...
    'Color','w','Position',[100 80 1300 840]);
id=unique([1:8:numel(t),numel(t)]);
subplot(2,2,1); plot(t(id)*1000,vout(id),'LineWidth',1); grid on;
yline(28,'--'); yline(27.44,':'); yline(28.56,':');
xlabel('Time (ms)'); ylabel('Output voltage (V)');
title('Precharged output; PWM starts at 3 ms');
subplot(2,2,2); plot(t(id)*1000,iL(id),'LineWidth',0.8); hold on;
plot(t(id)*1000,iout(id),'LineWidth',1); grid on;
xlabel('Time (ms)'); ylabel('Current (A)'); legend('Inductor / input','Load','Location','best');
title('Full-load currents');
iz=(numel(t)-10*p.pwmSteps):(numel(t)-1);
tz=(t(iz)-t(iz(1)))*1e6;
dv=1000*(vout(iz)-metrics.Vout_mean_V);
subplot(2,2,3); plot(tz,dv,'LineWidth',1); grid on;
xlim([tz(1),tz(end)]); ylim([min(dv)-3,max(dv)+3]);
xlabel('Time within steady window (us)'); ylabel('Vout - mean (mV)');
title(sprintf('Output ripple: %.2f mVpp',metrics.Vout_ripple_pp_mV));
subplot(2,2,4); plot(tz,iL(iz),'LineWidth',1); grid on;
xlim([tz(1),tz(end)]); ylim([min(iL(iz))-0.02,max(iL(iz))+0.02]);
xlabel('Time within steady window (us)'); ylabel('Inductor current (A)');
title(sprintf('IL ripple: %.3f App',metrics.IL_ripple_pp_A));
sgtitle(sprintf('24 V to %.4f V / %.4f A | Open-loop power-stage equivalent', ...
    metrics.Vout_mean_V,metrics.Iout_mean_A),'FontSize',15);
exportgraphics(f,fullfile(rootDir,'boost28v_results.png'),'Resolution',170);
exportgraphics(f,fullfile(rootDir,'boost28v_results.pdf'),'ContentType','vector');
savefig(f,fullfile(rootDir,'boost28v_results.fig'));
end
