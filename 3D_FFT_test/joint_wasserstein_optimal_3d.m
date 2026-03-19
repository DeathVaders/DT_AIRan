function [W, pairs] = joint_wasserstein_optimal_3d(az_true, el_true, tau_true, alpha_true, ...
                                          az_est,  el_est,  tau_est,  alpha_est)

    if isempty(az_true) || isempty(az_est)
        W = inf;
        return;
    end

    az_true = az_true(:);
    el_true = el_true(:);
    tau_true = tau_true(:);
    alpha_true = alpha_true(:);

    az_est = az_est(:);
    el_est = el_est(:);
    tau_est = tau_est(:);
    alpha_est = alpha_est(:);

    L_true = numel(az_true);
    L_est  = numel(az_est);

    if numel(el_true) ~= L_true || numel(tau_true) ~= L_true || numel(alpha_true) ~= L_true || ...
       numel(el_est)  ~= L_est  || numel(tau_est)  ~= L_est  || numel(alpha_est)  ~= L_est
        error('joint_wasserstein_optimal_3d: size mismatch between path vectors.');
    end

    tau_max = max([tau_true; 1e-12]);
    a_max   = max([abs(alpha_true); 1e-12]);

    %X = [az_true/180, ...
    %     (el_true + 90)/180, ...
    %     tau_true/tau_max, ...
    %     abs(alpha_true)/a_max];
%
    %Y = [az_est/180, ...
    %     (el_est + 90)/180, ...
    %     tau_est/tau_max, ...
    %     abs(alpha_est)/a_max];
%
    %C = pdist2(X, Y, 'euclidean');
%
    %% 最优一对一匹配，不考虑 unmatched 惩罚
    %pairs = matchpairs(C, 1e12);   % 1e12 只是个足够大的阈值
    %idx = sub2ind(size(C), pairs(:,1), pairs(:,2));
%
    %W = mean(C(idx));
     % =========================
    % 构造代价矩阵 C
    % =========================

    C = zeros(L_true, L_est);

    for i = 1:L_true
        for j = 1:L_est

            % az 周期角差
            d_az = abs(mod(az_true(i) - az_est(j) + 180, 360) - 180);

            % el 差
            d_el = abs(abs(el_true(i)) - abs(el_est(j)));

            % delay 差
            d_tau = abs(tau_true(i) - tau_est(j));

            % alpha 幅度差
            d_alpha = abs(abs(alpha_true(i)) - abs(alpha_est(j)));

            % 归一化 L1 代价
            C(i,j) = d_az/180 ...
                   + d_el/180 ...
                   + d_tau/tau_max ...
                   + d_alpha/a_max;

        end
    end

    % =========================
    % 最优匹配 (Hungarian)
    % =========================

    pairs = matchpairs(C, 1e12);

    % 匹配代价
    idx = sub2ind(size(C), pairs(:,1), pairs(:,2));
    W = mean(C(idx));

end