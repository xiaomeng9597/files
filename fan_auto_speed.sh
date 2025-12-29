#!/bin/bash
# fan_auto_speed.sh - 细腻线性调速版，根据CPU温度平滑调整风扇

TEMP_PATH="/sys/class/thermal/thermal_zone0/temp"
 if [ -f "/sys/class/hwmon/hwmon10/pwm1" ]; then
     PWM_PATH="/sys/class/hwmon/hwmon10/pwm1"
     PWM_ENABLE="/sys/class/hwmon/hwmon10/pwm1_enable"
 elif [ -f "/sys/class/hwmon/hwmon8/pwm1" ]; then
     PWM_PATH="/sys/class/hwmon/hwmon8/pwm1"
     PWM_ENABLE="/sys/class/hwmon/hwmon8/pwm1_enable"
 else
     echo "占空比文件不存在"
     exit 1
 fi

# 核心配置：自定义温度阈值和对应PWM值（可按需增删细化）
MIN_TEMP=50       # 风扇启动温度
LOW_TEMP=55       # 低转速阈值
MID_TEMP=60       # 中转速阈值
HIGH_TEMP=65      # 高转速阈值
MAX_TEMP=70       # 满速阈值

MIN_PWM=0         # 停转
LOW_PWM=120       # 低速
MID_PWM=179       # 中低速
MID_HIGH_PWM=191  # 中高速
HIGH_PWM=204      # 高速
MAX_PWM=255       # 满速

# 切换为手动模式并检查权限
if [ ! -w $PWM_ENABLE ]; then
    echo "错误：无权限操作 $PWM_ENABLE，请使用 sudo 运行"
    exit 1
fi
echo 1 > $PWM_ENABLE

# PWM值与等级映射
declare -A PWM_TO_LEVEL=( [0]=0 [120]=1 [179]=2 [191]=3 [204]=4 [255]=5 )

while true; do
    # 读取温度（m℃转℃，保留1位小数更精准）
    RAW_TEMP=$(cat $TEMP_PATH)
    TEMP=$(echo "scale=1; $RAW_TEMP / 1000" | bc -l)

    # 多挡位细腻调速逻辑
    if (( $(echo "$TEMP < $MIN_TEMP" | bc -l) )); then
        PWM=$MIN_PWM
    elif (( $(echo "$TEMP >= $MIN_TEMP && $TEMP < $LOW_TEMP" | bc -l) )); then
        PWM=$LOW_PWM
    elif (( $(echo "$TEMP >= $LOW_TEMP && $TEMP < $MID_TEMP" | bc -l) )); then
        PWM=$MID_PWM
    elif (( $(echo "$TEMP >= $MID_TEMP && $TEMP < $HIGH_TEMP" | bc -l) )); then
        PWM=$MID_HIGH_PWM
    elif (( $(echo "$TEMP >= $HIGH_TEMP && $TEMP < $MAX_TEMP" | bc -l) )); then
        PWM=$HIGH_PWM
    else
        PWM=$MAX_PWM
    fi

    # 应用PWM值并输出状态
    FAN_LEVEL=${PWM_TO_LEVEL[$PWM]}
    echo $PWM > $PWM_PATH
    echo "当前温度: ${TEMP}℃ | 风扇PWM值: ${PWM} | 风扇等级: ${FAN_LEVEL}"
    sleep 2
done
