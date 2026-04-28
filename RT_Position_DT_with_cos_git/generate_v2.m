if exist("BS_idx", "var") && exist("UE_idx", "var")
    fprintf("    Scenario BS%d / UE%d\n", BS_idx, UE_idx);
end
fprintf("    Using DT construction error level = %s%%\n", format_err_label(err_level * 100));

%% Channel generation setup
if ~exist("Nmc", "var")
    Nmc = 100;
end
nmse_samples = zeros(Nmc, 1);
sgcs_samples = zeros(Nmc, 1);
pdp_cos_samples = zeros(Nmc, 1);
az_cos_samples = zeros(Nmc, 1);
el_cos_samples = zeros(Nmc, 1);

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

build_pdp = @(delays_s, powers_w) local_build_pdp(delays_s, powers_w, PDP_delay_grid_s);
build_az_spectrum = @(az_deg, powers_w) local_build_angle_spectrum(az_deg, powers_w, AZ_angle_grid_deg);
build_el_spectrum = @(el_deg, powers_w) local_build_angle_spectrum(abs(el_deg), powers_w, EL_angle_grid_deg);

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
%%更改相对时延功率谱
    ToAs0_use = ToAs0 - min(ToAs0);
    PDP_ref = build_pdp(ToAs0_use, power);%这里要更改相对时延
    AZ_ref = build_az_spectrum(theta0, power);
    EL_ref = build_el_spectrum(elev0, power);

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
    PDP_ref = zeros(numel(PDP_delay_grid_s), 1);
    AZ_ref = zeros(numel(AZ_angle_grid_deg), 1);
    EL_ref = zeros(numel(EL_angle_grid_deg), 1);
end

vec_ref = H_ref(:);
den = sum(abs(vec_ref).^2);
norm_ref_sq = norm(vec_ref)^2;

%% 4) Monte Carlo: perturb AoA/ToA only
for mc = 1:Nmc
    if has_rays
        wrap180 = @(x) mod(x + 180, 360) - 180;
        sigma_az = err_level * 10;
        sigma_el = err_level * 10;
        L = numel(ToAs0);

        theta = wrap180(theta0 + (2 * rand(1, L) - 1) * sigma_az);
        elev = min(max(elev0 + (2 * rand(1, L) - 1) * sigma_el, -90), 90);
        minToA = min(ToAs0);
        %relToA = ToAs0 - minToA;
        relToA = 10e-9;
        dToA = (2 * rand(size(ToAs0)) - 1) .* (err_level * relToA);
        dToA(relToA == 0) = 0;
        ToAs = ToAs0 + dToA;
        perturbed_power = power;
%%更改相对时延
        ToAs_use = ToAs - min(ToAs);
        PDP_err = build_pdp(ToAs_use, perturbed_power);%%也要更改
        AZ_err = build_az_spectrum(theta, perturbed_power);
        EL_err = build_el_spectrum(elev, perturbed_power);

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
        PDP_err = zeros(numel(PDP_delay_grid_s), 1);
        AZ_err = zeros(numel(AZ_angle_grid_deg), 1);
        EL_err = zeros(numel(EL_angle_grid_deg), 1);
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

    pdp_cos_samples(mc) = local_cosine_similarity(PDP_ref, PDP_err);
    az_cos_samples(mc) = local_cosine_similarity(AZ_ref, AZ_err);
    el_cos_samples(mc) = local_cosine_similarity(EL_ref, EL_err);
end
fprintf("\nDone.\n");
toc;

function label = format_err_label(err_pct)
label = sprintf("%.3g", err_pct);
end

function pdp_out = local_build_pdp(delays_s, powers_w, delay_grid_s)
pdp_out = zeros(numel(delay_grid_s), 1);

if isempty(delays_s)
    return;
end

for l = 1:numel(delays_s)
    pdp_out = local_accumulate_linear(pdp_out, delay_grid_s, delays_s(l), powers_w(l));
end
end

function spec_out = local_build_angle_spectrum(angles_deg, powers_w, angle_grid_deg)
spec_out = zeros(numel(angle_grid_deg), 1);

if isempty(angles_deg)
    return;
end

for l = 1:numel(angles_deg)
    spec_out = local_accumulate_linear(spec_out, angle_grid_deg, angles_deg(l), powers_w(l));
end

total_power = sum(spec_out);
if total_power > 0
    spec_out = spec_out / total_power;
end
end

function vec_out = local_accumulate_linear(vec_in, grid, value, weight)
vec_out = vec_in;

if value <= grid(1)
    vec_out(1) = vec_out(1) + weight;
    return;
end

if value >= grid(end)
    vec_out(end) = vec_out(end) + weight;
    return;
end

right_idx = find(grid >= value, 1, "first");
left_idx = right_idx - 1;
left_grid = grid(left_idx);
right_grid = grid(right_idx);

if right_grid == left_grid
    vec_out(left_idx) = vec_out(left_idx) + weight;
    return;
end

right_weight = (value - left_grid) / (right_grid - left_grid);
left_weight = 1 - right_weight;

vec_out(left_idx) = vec_out(left_idx) + weight * left_weight;
vec_out(right_idx) = vec_out(right_idx) + weight * right_weight;
end

function cos_val = local_cosine_similarity(vec_a, vec_b)
norm_a = norm(vec_a);
norm_b = norm(vec_b);

if norm_a == 0 || norm_b == 0
    cos_val = 0;
else
    cos_val = dot(vec_a, vec_b) / (norm_a * norm_b);
end
end
