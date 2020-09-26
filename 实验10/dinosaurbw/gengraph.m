clear 
clc

% ����imread������ͼƬת��Ϊһ����ά����
image_array = imread('dinosaur_jump.jpg');

% ����size������ͼƬ���������ά�ȴ�С�������
% ��һάΪͼƬ�ĸ߶ȣ��ڶ�άΪͼƬ�Ŀ�ȣ�����άΪͼƬ��RGB����
[height,width,z]=size(image_array);   % 128*128*3

 imshow(image_array); % ��ʾͼƬ

red   = image_array(:,:,1); % ��ȡ��ɫ��������������Ϊuint8
green = image_array(:,:,2); % ��ȡ��ɫ��������������Ϊuint8
blue  = image_array(:,:,3); % ��ȡ��ɫ��������������Ϊuint8

% ������õ��˸������������һ��1ά��������reshape������������
% ʱ���ǰ����н�������ģ���������ǰ��Ҫ�ȰѸ��������������ת����
% ��������
% ����reshape��������Ժ����ں�����Ҫ������ƴ�ӣ�����Ϊ�˱������
% �����uint8���͵���������Ϊuint32����
r = uint32(reshape(red'   , 1 ,height*width));
g = uint32(reshape(green' , 1 ,height*width));
b = uint32(reshape(blue'  , 1 ,height*width));

% ��ʼ��Ҫд��.coe�ļ��е�RGB��ɫ����
rgb=zeros(1,height*width);

% ��Ϊ�����ͼƬ��24-bit���ɫͼƬ��ÿ������ռ��24-bit������RGB�ֱ�ռ��8-bit
% ����������Ҫ����12-bit������RGB�ֱ�Ϊ4-bit��������Ҫ�������
% 24-bit�����ݽ���������ƴ��
% bitshift()�����������Ƕ����ݽ�����λ���������е�һ��������Ҫ������λ�����ݣ��ڶ�������Ϊ������ʾ�����ƣ�Ϊ
% ������ʾ�����ƣ�����ϸ���÷�ֱ����Matlab��������� doc bitshift ���в鿴
% ��������Ժ�ɫ����������4λȡ����4λ��Ȼ������8λ��ΪROM��RGB���ݵĵ�11-bit����8-bit
% ����ɫ����������4λȡ����4λ��Ȼ������4λ��ΪROM��RGB���ݵĵ�7-bit����4-bit
% ����ɫ����������4λȡ����4λ��Ȼ������0λ��ΪROM��RGB���ݵĵ�3-bit����0-bit
for i = 1:height*width
    rgb(i) = bitshift(bitshift(r(i),-4),8) + bitshift(bitshift(g(i),-4),4) + bitshift(bitshift(b(i),-4),0);
end

fid = fopen( 'dinosaur_jump.coe', 'w+' );

% .coe�ļ�����ǰ��һ�б���Ϊ����ַ���������16��ʾ16����
fprintf( fid, 'memory_initialization_radix=16;\n');

% .coe�ļ��ĵڶ��б���Ϊ����ַ���
fprintf( fid, 'memory_initialization_vector =\n');

% ��rgb���ݵ�ǰ height*width-1  ������д��.coe�ļ��У�ÿ������֮���ö��Ÿ���
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

% ��rgb���ݵ����һ������д��.coe�ļ��У����÷ֺŽ�β
if (rgb(end)~=4095) 
    fprintf( fid, '000,');
else
    fprintf( fid, 'fff,');
end

fclose( fid ); % �ر��ļ�ָ��