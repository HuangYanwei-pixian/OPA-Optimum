## LCOPA Optimum by SPGD Algorithm
## PHI-Lab UESTC
## v1.0 WangYifan 2020.11.14

from pynq.overlays.base import BaseOverlay
from matplotlib import pyplot as plt
base = BaseOverlay("base.bit")

OPA_Driver = base.PS_AXI_0
from pynq.lib.video import *
import random
import time


Mode = VideoMode(640,480,24)
hdmi_out = base.video.hdmi_out
hdmi_out.configure(Mode,PIXEL_BGR)
hdmi_out.start()
# monitor (output) frame buffer size
frame_out_w = 1920
frame_out_h = 1080

# camera (input) configuration
#宽640，长480
frame_in_w = 640
frame_in_h = 480




# 定义三个接口的地址
OPA_EN = 0  # 使能信号，高代表数据有效，低代表空闲
OPA_DATA = 4  # 地址信号，从1-480，分别代表480组RGB电极
OPA_ADDR = 8  # 电压信号，宽度为24为，代表每一组RGB电极中的3个8位电压代码

#定义驱动电压列表
VolIn=[128]*1440
VolUp=[128]*1440
VolDn=[128]*1440
CODEtosent=[0]*480

VMIN=0
VMAX=255
#最小电压：0，最大电压代码：255
#设定正向随机电压
duup=[0]*1440
#设定负向随机电压
dudn=[0]*1440
du=[0]*1440
#定义迭代次数
ITERNUM=3000
iter=1
#定义deltaJ双边扰动的评价值

deltaJup=[0]*ITERNUM
deltaJdn=[0]*ITERNUM
J=[0]*ITERNUM
Xlable=[0]*ITERNUM

#定义评价函数
Jup=[0]*ITERNUM

Jdn=[0]*ITERNUM
#定义随机量和迭代步进
sig_rad=0.001
k_lamda=100

stringtemp=""


# initialize camera from OpenCV
import cv2

videoIn = cv2.VideoCapture(0)
videoIn.set(cv2.CAP_PROP_FRAME_WIDTH, frame_in_w);
videoIn.set(cv2.CAP_PROP_FRAME_HEIGHT, frame_in_h);

print("Capture device is open: " + str(videoIn.isOpened()))

for iter in range(ITERNUM):
    # 得到正向随机电压并与原始电压相加得到VolUp
    for i in range(1440):
        # 正向随机幅度为0-0.5Vmax
        duup[i] = random.randint(0, 1000) / 1000 * sig_rad * VMAX
        VolUp[i] = VolIn[i] + duup[i]
        if (VolUp[i] > VMAX):
            VolUp[i] = VMAX

        # 拼接功能：
    for i in range(480):
        stringtemp = format(int(VolUp[i * 3]), "x") + format(int(VolUp[i * 3 + 1]), "x") + format(int(VolUp[i * 3 + 2]),
                                                                                                  "x")
        CODEtosent[i] = int(stringtemp, 16)

    # 发送VolUp
    for i in range(480):
        OPA_Driver.write(OPA_EN, 1)  # 使能拉高
        OPA_Driver.write(OPA_ADDR, i + 1)  # 发送地址信号
        OPA_Driver.write(OPA_DATA, CODEtosent[i])  # 发送该地址对应的电压信号

    # 一组电压发送结束，使能信号拉低，接口回到空闲状态，同时数据也清零
    OPA_Driver.write(OPA_EN, 0)
    OPA_Driver.write(OPA_ADDR, 0)
    OPA_Driver.write(OPA_DATA, 0)

    # 休眠0.2s
    # time.sleep(0.2)

    # 采集评价函数并显示
    ret, frame_vga = videoIn.read()
    # Display webcam image via HDMI Out

    outframe = hdmi_out.newframe()
    outframe[0:480, 0:640, :] = frame_vga[0:480, 0:640, :]
    hdmi_out.writeframe(outframe)

    Jup[iter] = np.sum(frame_vga[235:245, 0:640, :]) / np.sum(frame_vga[0:480, 0:640, :])
    # 得到目标函数值deltaJup
    if iter == 1:
        deltaJup[iter] = 0
    else:
        deltaJup[iter] = Jup[iter] - J[iter - 1]

    # 得到负向随机电压并与原始电压相加得到Voldn
    for i in range(1440):
        # 负向随机幅度为0-0.5Vmax
        dudn[i] = random.randint(-1000, 0) / 1000 * sig_rad * VMAX
        VolDn[i] = VolIn[i] + dudn[i]
        if (VolDn[i] < VMIN):
            VolDn[i] = VMIN
            # 拼接功能：
    for i in range(480):
        stringtemp = format(int(VolDn[i * 3]), "x") + format(int(VolDn[i * 3 + 1]), "x") + format(int(VolDn[i * 3 + 2]),
                                                                                                  "x")
        CODEtosent[i] = int(stringtemp, 16)

    # 发送VolDn

    ADDR = 1
    while (ADDR <= 480):
        OPA_Driver.write(OPA_EN, 1)  # 使能拉高
        OPA_Driver.write(OPA_ADDR, ADDR)  # 发送地址信号
        OPA_Driver.write(OPA_DATA, CODEtosent[i])  # 发送该地址对应的电压信号
        ADDR += 1
    ADDR = 0
    # 一组电压发送结束，使能信号拉低，接口回到空闲状态，同时数据也清零
    OPA_Driver.write(OPA_EN, 0)
    OPA_Driver.write(OPA_ADDR, 0)
    OPA_Driver.write(OPA_DATA, 0)
    # 休眠0.2s
    # time.sleep(0.2)
    # 采集评价函数并显示
    ret, frame_vga = videoIn.read()

    # Display webcam image via HDMI Out

    outframe = hdmi_out.newframe()
    outframe[0:480, 0:640, :] = frame_vga[0:480, 0:640, :]
    hdmi_out.writeframe(outframe)
    # videoIn.release()
    # hdmi_out.stop()
    # del hdmi_out

    Jdn[iter] = np.sum(frame_vga[235:245, 0:640, :]) / np.sum(frame_vga[0:480, 0:640, :])
    if iter == 1:
        deltaJdn[iter] = 0
    else:
        deltaJdn[iter] = Jdn[iter] - J[iter - 1]
    if iter == 1:
        dj = 0
    else:
        dj = deltaJup[iter] - deltaJdn[iter]
    # 根据公式Un+1=Un+k*dj*du计算新的的电压，返回1
    for i in range(1440):
        du[i] = duup[i] - dudn[i]

    for m in range(1440):
        if (iter == 1):
            VolIn[m] = VolIn[m] + 150 * dj * du[m]
        else:
            VolIn[m] = VolIn[m] + k_lamda * dj * du[m]
        if (VolIn[m] >= VMAX):
            VolIn[m] = VMAX
        if (VolIn[m] <= VMIN):
            VolIn[m] = VMIN
    # 拼接功能：
    for i in range(480):
        stringtemp = format(int(VolIn[i * 3]), "x") + format(int(VolIn[i * 3 + 1]), "x") + format(int(VolIn[i * 3 + 2]),
                                                                                                  "x")
        CODEtosent[i] = int(stringtemp, 16)
    # 有可能会报错VolIn为负几
    # 发送VolIn
    ADDR = 1

    while (ADDR <= 480):
        OPA_Driver.write(OPA_EN, 1)  # 使能拉高
        OPA_Driver.write(OPA_ADDR, ADDR)  # 发送地址信号
        OPA_Driver.write(OPA_DATA, CODEtosent[i])  # 发送该地址对应的电压信号
        ADDR += 1
    ADDR = 0
    # 一组电压发送结束，使能信号拉低，接口回到空闲状态，同时数据也清零
    OPA_Driver.write(OPA_EN, 0)
    OPA_Driver.write(OPA_ADDR, 0)
    OPA_Driver.write(OPA_DATA, 0)
    # 休眠0.2s
    # time.sleep(0.2)
    # 采集评价函数并显示
    ret, frame_vga = videoIn.read()

    # Display webcam image via HDMI Out

    outframe = hdmi_out.newframe()
    outframe[0:480, 0:640, :] = frame_vga[0:480, 0:640, :]
    hdmi_out.writeframe(outframe)
    # videoIn.release()
    # hdmi_out.stop()
    # del hdmi_out
    J[iter] = np.sum(frame_vga[235:245, 0:640, :]) / np.sum(frame_vga[0:480, 0:640, :])

    if (iter % 100 == 0):
        print(iter)

    iter += 1


for iter in range(ITERNUM):
    Xlable[iter]=iter+1
plt.plot(Xlable,J)

