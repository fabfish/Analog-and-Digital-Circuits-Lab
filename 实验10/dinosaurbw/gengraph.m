clear 
clc

% 利用imread函数把图片转化为一个三维矩阵
image_array = imread('dinosaur_jump.jpg');

% 利用size函数把图片矩阵的三个维度大小计算出来
% 第一维为图片的高度，第二维为图片的宽度，第三维为图片的RGB分量
[height,width,z]=size(image_array);   % 128*128*3

 imshow(image_array); % 显示图片

red   = image_array(:,:,1); % 提取红色分量，数据类型为uint8
green = image_array(:,:,2); % 提取绿色分量，数据类型为uint8
blue  = image_array(:,:,3); % 提取蓝色分量，数据类型为uint8

% 把上面得到了各个分量重组成一个1维矩阵，由于reshape函数重组矩阵的
% 时候是按照列进行重组的，所以重组前需要先把各个分量矩阵进行转置以
% 后在重组
% 利用reshape重组完毕以后，由于后面需要对数据拼接，所以为了避免溢出
% 这里把uint8类型的数据扩大为uint32类型
r = uint32(reshape(red'   , 1 ,height*width));
g = uint32(reshape(green' , 1 ,height*width));
b = uint32(reshape(blue'  , 1 ,height*width));

% 初始化要写入.coe文件中的RGB颜色矩阵
rgb=zeros(1,height*width);

% 因为导入的图片是24-bit真彩色图片，每个像素占用24-bit，其中RGB分别占用8-bit
% 而我这里需要的是12-bit，其中RGB分别为4-bit，所以需要在这里对
% 24-bit的数据进行重组与拼接
% bitshift()函数的作用是对数据进行移位操作，其中第一个参数是要进行移位的数据，第二个参数为负数表示向右移，为
% 正数表示向左移，更详细的用法直接在Matlab命令窗口输入 doc bitshift 进行查看
% 所以这里对红色分量先右移4位取出高4位，然后左移8位作为ROM中RGB数据的第11-bit到第8-bit
% 对绿色分量先右移4位取出高4位，然后左移4位作为ROM中RGB数据的第7-bit到第4-bit
% 对蓝色分量先右移4位取出高4位，然后左移0位作为ROM中RGB数据的第3-bit到第0-bit
for i = 1:height*width
    rgb(i) = bitshift(bitshift(r(i),-4),8) + bitshift(bitshift(g(i),-4),4) + bitshift(bitshift(b(i),-4),0);
end

fid = fopen( 'dinosaur_jump.coe', 'w+' );

% .coe文件的最前面一行必须为这个字符串，其中16表示16进制
fprintf( fid, 'memory_initialization_radix=16;\n');

% .coe文件的第二行必须为这个字符串
fprintf( fid, 'memory_initialization_vector =\n');

% 把rgb数据的前 height*width-1  个数据写入.coe文件中，每个数据之间用逗号隔开
% fprintf( fid, '%x,\n',rgb(1:end-1));
for i = 1:height-1
    for j = (i-1)*width+1:i*width
        if (rgb(j)~=4095) 
            fprintf( fid, '000,');
        else
            fprintf( fid, 'fff,');
        end
    end
    fprintf( fid, '\n');
end

for i = (height-1)*width+1:height*width-1
    if (rgb(j)~=4095) 
        fprintf( fid, '000,');
    else
        fprintf( fid, 'fff,');
    end
end

% 把rgb数据的最后一个数据写入.coe文件中，并用分号结尾
if (rgb(end)~=4095) 
    fprintf( fid, '000,');
else
    fprintf( fid, 'fff,');
end

fclose( fid ); % 关闭文件指针