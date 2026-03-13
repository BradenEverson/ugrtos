import serial
import sys

if __name__ == "__main__":
    port = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyACM0"
    file = sys.argv[2] if len(sys.argv) > 2 else "data.csv"
    file = "data/" + file

    ser = None

    try:
        ser = serial.Serial(port, baudrate=115200)
    except:
        print(f"Failed to open port: {port}")
        sys.exit(1)

    done = False

    with open(file, "w") as f:
        try:
            f.write("task_id,timestamp,total_run_timf,total_io_wait_time,total_ready_wait_time,wait_pct,delta\n")
            while not done:
                line_bytes = ser.readline()
                parse = line_bytes.decode('utf-8').strip()

                if not parse:
                    continue

                f.write(parse + '\n')
                f.flush()
                print(f"{parse}")
        except KeyboardInterrupt:
            done = True

    ser.close()
