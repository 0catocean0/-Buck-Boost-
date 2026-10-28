function write_merged_csv()
% Export plotting samples and fine switching data from the actual saved run.
root=fileparts(mfilename('fullpath'));
q=load(fullfile(root,'merged_data.mat'),'data'); d=q.data;
stride=30;
idx=1:stride:numel(d.t);
write(idx,'merged_full_trace_1us.csv');
idx=find(d.t>=0.0198 & d.t<=0.0208);
write(idx,'merged_switch_zoom.csv');
idx=find((d.t>=0.0188 & d.t<0.019) | (d.t>=0.0388 & d.t<0.039));
write(idx,'merged_steady_windows.csv');
    function write(k,name)
        tab=table(d.t(k),d.Vload(k),d.Iload(k),d.Vbuck(k),d.Vboost(k), ...
            d.buck16v_IL(k),d.boost28v_IL(k),'VariableNames', ...
            {'Time_s','Vload_V','Iload_A','Vbuck_V','Vboost_V','ILbuck_A','ILboost_A'});
        writetable(tab,fullfile(root,name));
    end
end
