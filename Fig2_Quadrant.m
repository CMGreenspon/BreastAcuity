%% Load QuadrantData from each participant
data_path = fullfile(DataPath(), 'raw_data', 'quadrant');
flist = dir(fullfile(data_path, '*.mat'));
pooledData = struct();
for f = 1:length(flist)
    temp = load(fullfile(data_path, flist(f).name));
    pooledData(f).Subject = temp.data.subjID;
    pooledData(f).areola = temp.data.areola;
    pooledData(f).nipple = temp.data.nipple;
end
clearvars -except pooledData
nSubjects = length(pooledData);


%% For each participant what is the odds of getting x% correct
% Compute percent correct for each subject
[ar_pc, nip_pc] = deal(zeros(nSubjects, 1));
for i = 1:nSubjects
    ar_pc(i) = sum(pooledData(i).areola.location == pooledData(i).areola.stylusresponse) / ...
        length(pooledData(i).areola.location);
    nip_pc(i) = sum(pooledData(i).nipple.location == pooledData(i).nipple.stylusresponse) / ...
        length(pooledData(i).nipple.location);
end

% Simulate odds assuming random guessing for each participant
num_perms = 1e4; % 10k guesses
meta_null = zeros(nSubjects, num_perms, 2); % Keep track of null for each participant
% Technically the nulls would be the same for areola and nipple but we'll keep them separate for added rigour
Classes = unique(pooledData(1).areola.location); % Classes are the same across participants and were equally delivered
[ar_pc_p, nip_pc_p] = deal(zeros(nSubjects, 1)); % pValue for each participant:location
for i = 1:nSubjects
    % Get number of trials for each participant (not sure why it varies)
    naTrials = length(pooledData(i).areola.location);
    nnTrials = length(pooledData(i).nipple.location);
    % Guess for each trial p times (sample with replacement)
    null = zeros(num_perms, 2); % Do areola and nipple separately
    for p = 1:num_perms
        guesses = datasample(Classes, naTrials);
        null(p,1) = sum(guesses == pooledData(i).areola.location) / naTrials;
        guesses = datasample(Classes, nnTrials);
        null(p,2) = sum(guesses == pooledData(i).nipple.location) / nnTrials;
    end
    % Determine the proportion of times our performance exceeded the null and perform one sided test
    ar_pc_p(i) = 1 - (sum(ar_pc(i) > null(:,1)) / num_perms);
    nip_pc_p(i) = 1 - (sum(nip_pc(i) > null(:,2)) / num_perms);
    % Allocate to meta null for cross-participant analysis
    meta_null(i,:,:) = null;
end
% Bonferroni correction
ar_pc_p = ar_pc_p .* nSubjects;
ar_pc_h = ar_pc_p < 0.05;
nip_pc_p = nip_pc_p .* nSubjects;
nip_pc_h = nip_pc_p < 0.05;

% Average across participants in meta_null to get cross-participant null
meta_null_mean = squeeze(mean(meta_null, 1));
meta_null_std = std(meta_null_mean, 1, 1);
% Compute p-value and standardized effect size (z-score) for nipple and areola
ar_meta_pc_p = 1 - (sum(mean(ar_pc) > meta_null_mean(:,1)) / num_perms);
ar_meta_pc_z = (mean(ar_pc) - mean(meta_null_mean(:,1))) / meta_null_std(1);
nip_meta_pc_p = 1 - (sum(mean(nip_pc) > meta_null_mean(:,2)) / num_perms);
nip_meta_pc_z = (mean(nip_pc) - mean(meta_null_mean(:,2))) / meta_null_std(2);

% Print number of participants who performed above chance
fprintf('%d / %d subjects performed better than chance (areola). Z = %0.3f; p = %0.3f\n', ...
    sum(ar_pc_h), nSubjects, ar_meta_pc_z, ar_meta_pc_p)
fprintf('%d / %d subjects performed better than chance (nipple). Z = %0.3f; p = %0.3f\n', ...
    sum(nip_pc_h), nSubjects, nip_meta_pc_z, nip_meta_pc_p)


%% Make subject data structure & load measurements
subjectMeta = readtable(fullfile(DataPath(), 'raw_data', 'SubjectMeta.xlsx'));
sl = {pooledData.Subject};

subjectData = struct();
meas_table = NaN(length(sl), 3);
for s = 1:length(sl)
    subjectData(s).Subject = sl{s};
    if contains(sl{s}, 'NotNumbered')
        continue
    end
    % Add measurements field
    meta_idx = strcmp(subjectMeta.Subject, strrep(sl{s}, '_', '-'));
    if sum(meta_idx) ~= 1
        [subjectData(s).measurements.bust, subjectData(s).measurements.underbust] = deal(nan);
        continue
    end
    subjectData(s).measurements.bust = subjectMeta.bust(meta_idx);
    subjectData(s).measurements.underbust = subjectMeta.underbust(meta_idx);
    meas_table(s,1) = subjectMeta.bust(meta_idx);
    meas_table(s,2) = subjectMeta.underbust(meta_idx);
    meas_table(s,3) = meas_table(s,1) - meas_table(s,2);
end


%% Make figure
nipple_color = [0.26 0.63 0.28];
areola_color = [0.26 0.28 0.63];

clf;
set(gcf, 'Units', 'Inches', 'Position', [30 1 6.45 2.25])
axes('Position', [0.0 0.125 0.3 0.75]); hold on
    % Plot cross
    plot([-1 1], [-1 1], 'Color', [.6 .6 .6])
    plot([-1 1], [1 -1], 'Color', [.6 .6 .6])
    % Plot circles
    x = linspace(0, 2*pi, 500);
    r = 0.4;
    plot(sin(x) .* r, cos(x) .* r, 'color', [.6 .6 .6])
    r = 1;
    plot(sin(x) .* r, cos(x) .* r, 'color', [.6 .6 .6])
    % Scatter points
    x = linspace(0, 1.5*pi, 4);
    r = 0.2; % Half radius of inner ring
    scatter(sin(x) .* r, cos(x) .* r, 30, nipple_color, 'filled')
    r = 0.7; % Half way between inner and outer ring
    scatter(sin(x) .* r, cos(x) .* r, 30, areola_color, 'filled')
    % Add text
    text(1.25, 0, 'Medial', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Rotation', -90)
    text(-1.25, 0, 'Lateral', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Rotation', 90)
    text(0, 1.25, 'Superior', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom')
    text(0, -1.25, 'Inferior', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top')

    set(gca, 'DataAspectRatio', [1 1 1], ...
             'XLim', [-2 2], ...
             'XColor', 'none', ...
             'YColor', 'none')

axes('Position', [0.375 0.2 0.25 0.7]); hold on
    x = [0.5 0.5 1.5 1.5];
    y = [0 1 1 0];
    ww = 0.25;

    % Areola bar
    am = mean(ar_pc);
    as = std(ar_pc);
    patch(x, y .* am, areola_color, 'EdgeColor','none', 'FaceAlpha', 0.2)
    plot(x, y .* am, 'Color', 'k')
    wc = 1;
    plot([wc-ww, wc+ww, wc, wc, wc-ww, wc+ww], [am-as, am-as, am-as, am+as, am+as, am+as], 'Color', 'k')

    % Nipple bar
    nm = mean(nip_pc);
    ns = std(nip_pc);
    patch(x + 1.5, y .* nm, nipple_color, 'EdgeColor','none', 'FaceAlpha', 0.2)
    plot(x + 1.5, y .* nm, 'Color', 'k')
    wc = 2.5;
    plot([wc-ww, wc+ww, wc, wc, wc-ww, wc+ww], [nm-ns, nm-ns, nm-ns, nm+ns, nm+ns, nm+ns], 'Color', 'k')

    % Lines between points
    x = repmat([1, 2.5, NaN], [nSubjects, 1])';
    y = [ar_pc, nip_pc, NaN(nSubjects, 1)]';
    plot(x(:), y(:), 'Color', [.4 .4 .4], 'LineWidth', 0.5)
    % Individual points (filled = significant)
    scatter(ones(sum(ar_pc_h),1), ar_pc(ar_pc_h), 50, areola_color, 'MarkerFaceColor', areola_color)
    scatter(ones(sum(~ar_pc_h),1), ar_pc(~ar_pc_h), 50, areola_color)
    scatter(ones(sum(nip_pc_h),1) .* 2.5, nip_pc(nip_pc_h), 50, nipple_color, 'MarkerFaceColor', nipple_color)
    scatter(ones(sum(~nip_pc_h),1) .* 2.5, nip_pc(~nip_pc_h), 50, nipple_color)

    % Plot chance
    plot([0 3.5], [0.25 0.25], 'Color', [.4 .4 .4], 'LineStyle', '--')


    set(gca, 'XLim', [0 3.5], ...
             'YLim', [0 1], ...
             'YTick', [0:.25:1], ...
             'XTick', [1, 2.5], ...
             'XTickLabel', {'Areola', 'Nipple'})
    ylabel('p(correct)')

axes('Position', [0.725 0.2 0.225 0.7]); hold on
    plot([50, 325], [.25 .25], 'Color', [.6 .6 .6], 'LineStyle','--')
    xx = [70, 310];
    c = lines(3);
    i = 3;
    nan_idx = isnan(meas_table(:,i));
    x = meas_table(~nan_idx,i) .* 25.4;
    % Areola
    y = ar_pc(~nan_idx);
    [r,p] = corr(x,y);
    p1 = polyfit(x, y, 1);
    plot(xx, polyval(p1, xx), 'Color', areola_color, 'LineStyle', '--')
    scatter(x, y, 30, areola_color, 'MarkerFaceColor', areola_color)
    % Niple
    y = nip_pc(~nan_idx);
    [r,p] = corr(x,y);
    p1 = polyfit(x, y, 1);
    plot(xx, polyval(p1, xx), 'Color', nipple_color, 'LineStyle', '--')
    scatter(x, y, 30, nipple_color, 'MarkerFaceColor', nipple_color)
    xlabel(sprintf('%s Bust (mm)', GetUnicodeChar('Delta')))
    ylabel('p(correct)')
    set(gca, 'XLim', [50, 325], ...
             'YLim', [0 1], ...
             'XTick', [100:100:300], ...
             'YTick', [.25:.25:1])

AddFigureLabels(gcf, [.05, -.05])

shg
print(gcf, fullfile(FigurePath, "Fig2_Quadrant.png"), '-dpng', '-r300')