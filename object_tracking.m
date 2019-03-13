function object_tracking(padding, output_sigma_factor, videoInd, etha, minItr, maxItr, ini_im)

%   -----------------------------------------------------------
%   Add the pathes of functions and filters
addpath('Helper Functions/');
% addpath ('../../benchmarks/');
addpath ('CFwLB/');

vis = 0; % to visualize the response and filter
Visfilt = 0; % to visualize training process of the filter
visTracking = 1;

clips = {'faceocc'};
%   -----------------------------------------------------------
%   Load the frames and ground truth annotation and ini position of target
base_path = '/media/cjh/datasets/tracking/OTB100/';
video = choose_video(base_path);
video_path = fullfile(base_path, video);
% video_path = 'faceocc_frames/';
[img_files, pos, target_sz, resize_image, ground_truth, ...
    video_path, resize_scale] = load_video_info(video_path);

%window size, taking padding into account
s_filt_size = floor(target_sz ); % the size of small filter
b_filt_size = floor(target_sz * (1 + padding)); % the size of big filter
output_sigma = sqrt(prod(s_filt_size)) * output_sigma_factor;
% output_sigma = 1;

%desired output (gaussian shaped), bandwidth proportional to target size
sz = b_filt_size;
[rs, cs] = ndgrid((1:sz(1)) - floor(sz(1)/2), (1:sz(2)) - floor(sz(2)/2));
y = exp(-0.5 / output_sigma^2 * (rs.^2 + cs.^2));
y = circshift(y, fix(s_filt_size/2));
yf = fftvec(y(:), b_filt_size);

if resize_image,
    ground_truth = fix(ground_truth/resize_scale);
end;

% dump variables
positions = zeros(length(ground_truth)-4, 2);  %to calculate precision
psr = zeros(length(ground_truth)-4, 1);  %to calculate precision
runTime = zeros(length(ground_truth)-4, 1);  %to calculate precision
MMx = prod(b_filt_size);
ZX = zeros(MMx, 1);
ZZ = zeros(MMx, 1);
term = 1e-6;

hfig = figure;
for frame = 1:length(ground_truth)-4
    df = zeros(prod(b_filt_size), 1);
    sf = zeros(prod(b_filt_size), 1);
    Ldsf  = zeros(prod(b_filt_size), 1);
  
    im = imread([video_path '/img/' img_files(frame).name]);
    imcolor = im;
    if size(im,3) > 1,
        im = rgb2gray(im);
    end
    if resize_image,
        im = imresize(im, 1/resize_scale);
        imcolor = imresize(imcolor,1/resize_scale);
    end

    %extract and pre-process subwindow
    if frame == 1,  %first frame, train with random image

        [ypos xpos x] = get_subwindow(im, pos , b_filt_size);
        if ini_im
            ini_imgs = get_ini_perturbation(x, 8);
        else  
            ini_imgs = x(:);
        end;

        ECFimageF = fftvec(ini_imgs, b_filt_size);

        for n = 1:size(ini_imgs, 2)
            ZX = ZX + bsxfun(@times, conj(ECFimageF(:,n)), yf);
            ZZ = ZZ + bsxfun(@times, conj(ECFimageF(:,n)), ECFimageF(:,n));
        end

        positions(frame,:)=pos;
        runTime(frame) = 0;

    else
        startTime = tic ;
        [df sf Ldsf mu] = ECF(yf, b_filt_size, 1, s_filt_size, term, minItr, maxItr, sf, df, Ldsf,ZZ,ZX, Visfilt);
        [ypos xpos cropIm] = get_subwindow(im, pos , b_filt_size);
        [rsp posRsp] = get_rsp((double(cropIm)), df, s_filt_size, b_filt_size); %gcf

        rspTmp = rsp(posRsp(1)-floor(s_filt_size(1)/2):posRsp(1)+floor(s_filt_size(1)/2), ...
            posRsp(2)-floor(s_filt_size(2)/2):posRsp(2)+floor(s_filt_size(2)/2));

        imTmp = cropIm(posRsp(1)-floor(s_filt_size(1)/2):posRsp(1)+floor(s_filt_size(1)/2), ...
            posRsp(2)-floor(s_filt_size(2)/2):posRsp(2)+floor(s_filt_size(2)/2));

        [row, col] = find(rsp == max(rsp(:)), 1);
        pos = pos - floor(b_filt_size/2) + [row, col];

        if resize_image
            dis= sqrt(sum((pos*resize_scale - ground_truth(frame,:)*resize_scale).^2));
        else
            dis= sqrt(sum((pos - ground_truth(frame,:)).^2));
        end;
        positions(frame,:)=pos;

        [yt xt x] = get_subwindow(im, pos , b_filt_size);
        xf = fftvec(x(:), b_filt_size);
        ZX = ((1-etha) * ZX) + (etha *  conj(xf) .* yf);
        ZZ = ((1-etha) * ZZ) + (etha * conj(xf) .* xf);
        endTime = toc(startTime);
        runTime(frame) = endTime;

        if vis
            d = ifftvec((df), b_filt_size, b_filt_size);
            d = reshape(d, b_filt_size);
            d = d(1:s_filt_size(1) , 1:s_filt_size(2));
            d = flipud(fliplr(d));

            imTmp = imresize(imTmp, size(d));
            rspTmp = imresize(rspTmp, size(d));
            rspTmp = rspTmp.*rspTmp;

            imTmp = imTmp + abs(min(imTmp(:)));
            imTmp = imTmp /max(imTmp(:));

            rspTmp = rspTmp + abs(min(rspTmp(:)));
            rspTmp = rspTmp /max(rspTmp(:));

            d = d + abs(min(d(:)));
            d = d /max(d(:));

            rspImFilt = [imTmp , d  , rspTmp];

            w=300;
            h=w*(size(rspImFilt,1)/size(rspImFilt,2));
            set(hfig, 'Position', [0 0 w h]);
            imagesc(rspImFilt); colormap gray;axis image;axis off;
            set(hfig, 'PaperPosition', [0 0 3 2.5]); %Position plot at left hand corner with width 5 and height 5.
            set(hfig, 'PaperSize', [3 2.5]); %Set the paper to have width 5 and height 5.

            print('-dtiff', [clips{videoInd} '\' num2str(frame) '.png']);
        end;
    end;

    %visualization
    if visTracking
        rect_position = [pos([2,1]) - target_sz([2,1])/2, target_sz([2,1])];
        gt = ground_truth(frame, :);
        rect_position2 = [gt([2 1]) - target_sz([2,1])/2, target_sz([2,1])];
        if frame == 1,  %first frame, create GUI
            figure(1);
            im_handle = imshow(imcolor, 'Border','tight', 'InitialMag',200);
            rect_handle = rectangle('Position',rect_position, 'EdgeColor','g', 'LineWidth',3, 'LineStyle','-.');
            rect_handle2 = rectangle('Position',rect_position2, 'EdgeColor','r');
            t_cfwlb = text('Position',rect_position([1 2]),'String','CfwLb','FontSize',14, 'Color','g');
            t_gt = text('Position',rect_position2([1 2]),'String','GT','FontSize',12,'Color','r');

        else
            try  %subsequent frames, update GUI
                set(im_handle, 'CData', imcolor)
                set(rect_handle, 'Position', rect_position)
                set(rect_handle2, 'Position', rect_position2)
                set(t_cfwlb, 'Position',rect_position([1 2]));
                set(t_gt, 'Position',rect_position2([1 2]));
            catch  %#ok, user has closed the window
                return
            end
        end
        drawnow
    end;

end;
%% end of algo, saving the results
if resize_image
    positions = positions * resize_scale;
    target_sz = resize_scale*target_sz;
    ground_truth = resize_scale * ground_truth;
end;
clipName = clips{videoInd};

posDis = sqrt(sum((positions(1:frame,:)-ground_truth(1:frame,:)).^2,2));

errMore20 = sum(posDis>20);
accAt20 = (frame-errMore20)/frame
avgError = sum(posDis)/frame
 
fps = frame/sum(runTime)

% save(['tracking1_64\' clips{videoInd} '_Itr_' num2str(maxItr) '_pad_' num2str(padding) '_etha_' num2str(etha) '.mat' ], ...
%     'positions', 'ground_truth', 'etha', 'padding' , 'maxItr', 'psr', 'runTime', 'clipName', 'frame', 'target_sz', 'ini_im', 'accAt20', 'avgError','fps');

end