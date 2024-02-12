import sys,os.path,re,getopt,json
from types import SimpleNamespace
from pod.cpu import CpuResource,CpuSet

procstatus = '/proc/self/status'
obj_save_dir = ""
obj_save_name="cpu.json"

def save_obj_in_file(obj, file):
    with open(file, 'w') as f:
        json.dump({"available": obj.available}, f)

def read_obj_from_file(file):
    with open(file, 'r') as f:
        return json.load(f)["available"]

def main(name, argv):
    global procstatus, obj_save_dir, obj_save_name
    helpstr = name + " --proc=<proc status path, default /proc/self/status>"\
                     " --dir=<data cache directory>"\
                     " allocate-core | allocate-cpu-mask <num> | cpuset-substract str1 str2"\
                     "\n"
    try:
        opts, args = getopt.getopt(argv,"h",["proc=", "dir="])
    except getopt.GetoptError:
        print(helpstr)
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            print(helpstr)
            sys.exit()
        elif opt in ("--proc"):
            procstatus = arg
        elif opt in ("--dir"):
            obj_save_dir = arg

    if len(args) == 0:
        print(helpstr)
        sys.exit(2)

    obj_save_path = obj_save_dir + obj_save_name

    if os.path.isfile(obj_save_path):
        cpursc = CpuResource("", False, read_obj_from_file(obj_save_path))
    else:
        status_content = open(procstatus).read().rstrip('\n')
        cpursc = CpuResource(status_content, False)

    if args[0] == "allocate-core":
        print(cpursc.allocate_whole_core())
        save_obj_in_file(cpursc, obj_save_path)
    elif args[0] == "allocate-cpu-mask":
        if len(args) != 2:
           print("Try again with: allocate-cpu-mask <number of threads>")
           sys.exit(2) 
        print(cpursc.allocate_siblings_mask(int(args[1])))
        save_obj_in_file(cpursc, obj_save_path)
    elif args[0] == "cpuset-substract":
        if len(args) != 3:
            print("Try again with: cpuset-substract <cpuset1 string> <cpuset2 string>")
            sys.exit(2)
        cpuset = CpuSet(args[1])
        cpuset.substract(args[2])
        print(cpuset.cpuset_str())
    else:
        print(helpstr)
        sys.exit(2)

if __name__ == "__main__":
     main(sys.argv[0], sys.argv[1:])


