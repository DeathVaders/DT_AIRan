fprintf("    Using DT construction error level = %s%%\n", format_err_label(err_level * 100));

%% Channel generation setup
if ~exist("Nmc", "var")
    Nmc = 100;
end
nmse_samples = zeros(Nmc, 1);
sgcs_samples = zeros(Nmc, 1);

pm = propagationModel("raytracing");
pm.AngularSeparation = "low";
pm.MaxNumReflections = MaxNumReflections;
pm.MaxRelativePathLoss = MaxRelativePathLoss;
pm.MaxNumDiffractions = MaxNumDiffractions;

tic;
fprintf("Start channel generation...\n");

%% 1) Ray tracing only once at the true geometry
UE_loc_true = UE_loc;
UE = rxsite("Latitude", UE_loc_true(1), "Longitude", UE_loc_true(2), ...
            "AntennaHeight", UE_height, "AntennaAngle", Rx_rotation);

rays = raytrace(BS, UE, pm);
has_rays = ~isempty(rays{1});

%% 2) UE array indices
[mx, my] = ndgrid(0:Nx-1, 0:Ny-1);

%% 3) Extract physical parameters at true geometry
if has_rays
    fprintf("Number of paths: %d\n", length(rays{1}));

    N_use = length(rays{1});
    fprintf("Using %d paths \n", N_use);

    rays_used = rays{1}(1:N_use);
    pathAoAs0 = [rays_used.AngleOfArrival];

    theta0 = pathAoAs0(1, :);
    elev0 = pathAoAs0(2, :);
    power_dB = -[rays_used.PathLoss];
    ToAs0 = [rays_used.PropagationDelay];
    phases = [rays_used.PhaseShift];
    power = 1e-3 * (10.^(0.1 * (power_dB + 30)));

    H_ref = zeros(Nx, Ny, Nc);
    for l = 1:length(ToAs0)
        rx_response_l = exp(1j * 2 * pi * Rx_ant_spacing * ...
            (mx * cosd(elev0(l)) * cosd(theta0(l)) + ...
             my * cosd(elev0(l)) * sind(theta0(l))));
        freq_response_l = exp(-1j * 2 * pi * f_k * ToAs0(l));
        alpha_l = sqrt(power(l) / Nc) * exp(1j * phases(l));
        H_ref = H_ref + alpha_l .* rx_response_l .* reshape(freq_response_l, 1, 1, Nc);
    end
else
    H_ref = zeros(Nx, Ny, Nc);
end

vec_ref = H_ref(:);
den = sum(abs(vec_ref).^2);
norm_ref_sq = norm(vec_ref)^2;

%% 4) Monte Carlo: perturb AoA/ToA only
for mc = 1:Nmc
    if has_rays
        wrap180 = @(x) mod(x + 180, 360) - 180;
        sigma_az = err_level * 360;
        sigma_el = err_level * 90;
        L = numel(ToAs0);

        theta = wrap180(theta0 + (2 * rand(1, L) - 1) * sigma_az);
        elev = min(max(elev0 + (2 * rand(1, L) - 1) * sigma_el, -90), 90);
        minToA = min(ToAs0);
        relToA = ToAs0 - minToA;
        dToA = (2 * rand(size(ToAs0)) - 1) .* (err_level * relToA);
        dToA(relToA == 0) = 0;
        ToAs = ToAs0 + dToA;

        channel = zeros(Nx, Ny, Nc);
        for l = 1:L
            rx_response_l = exp(1j * 2 * pi * Rx_ant_spacing * ...
                (mx * cosd(elev(l)) * cosd(theta(l)) + ...
                 my * cosd(elev(l)) * sind(theta(l))));
            freq_response_l = exp(-1j * 2 * pi * f_k * ToAs(l));
            alpha_l = sqrt(power(l) / Nc) * exp(1j * phases(l));
            channel = channel + alpha_l .* rx_response_l .* reshape(freq_response_l, 1, 1, Nc);
        end
    else
        channel = zeros(Nx, Ny, Nc);
    end

    diff_t = channel - H_ref;
    num = sum(abs(diff_t(:)).^2);
    dot_ref_k = sum(conj(H_ref(:)) .* channel(:));
    norm_k_sq = sum(abs(channel(:)).^2);

    if den == 0
        nmse_samples(mc) = 0;
    else
        nmse_samples(mc) = num / den;
    end

    if norm_ref_sq == 0 || norm_k_sq == 0
        sgcs_samples(mc) = 0;
    else
        sgcs_samples(mc) = abs(dot_ref_k)^2 / (norm_ref_sq * norm_k_sq);
    end
end
fprintf("\nDone.\n");
toc;

function label = format_err_label(err_pct)
label = sprintf("%.3g", err_pct);
end
