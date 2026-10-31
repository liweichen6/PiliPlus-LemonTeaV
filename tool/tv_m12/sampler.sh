#!/system/bin/sh
# M12 crash-debug sampler, run on the TV by tool/tv_m12/run.sh: every 2 s the
# uptime, load, CPU clock and free memory; every 10 s the temperature. Every
# 30 s a wake-up key, so the screensaver doesn't start: its photo player takes
# the hardware JPEG decoder, and then no 4K hardware video decoder can open.
n=0
while true; do
  read up rest < /proc/uptime
  read l1 l5 l15 rest < /proc/loadavg
  read f0 < /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
  avail=$(grep MemAvailable /proc/meminfo)
  swap=$(grep SwapFree /proc/meminfo)
  line="S up=${up} load=${l1} cpu0=${f0} ${avail} ${swap}"
  if [ $((n % 5)) -eq 0 ]; then
    t=$(dumpsys thermalservice 2>/dev/null | grep -m 1 'mName=CPU')
    line="${line} ${t}"
  fi
  echo "${line}"
  if [ $((n % 15)) -eq 14 ]; then input keyevent KEYCODE_WAKEUP; fi
  n=$((n + 1))
  sleep 2
done
