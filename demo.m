% # of iteration to optimize ADMM
% iteration = [ 1 2 4 8 16 32 64];
iteration = 2;

% the portion of frame that I used to train the smaller filter
padding = 2 ;

% Etha is the updating factor at each frame. refer to the paper
% etha = [0.025 0.05 0.075 0.1 .125];
% 
output_sigma_factor = 1/16;

% initial the tracker at the first frame using 
% 8 images are generated by small rotation, scaling, transaction. 
ini_imgs = 1;

v = 1; % demo for david tracking.
% The etha values are borrowd from other papers for the videos
etha = .025;  

object_tracking(padding, output_sigma_factor, 1, etha, 1, iteration, ini_imgs);


   