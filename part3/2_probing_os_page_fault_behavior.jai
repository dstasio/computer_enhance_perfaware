#load "platform_metrics.jai";

Type :: enum {
    Forward;
    Backward;
    Forward_Skipping;
}
TYPE       :: Type.Forward;
SKIP_WRITE :: 1024;
SKIP_IDLE  :: 512;
INSPECT_ADDRESSES :: false;

#assert(!INSPECT_ADDRESSES || TYPE == .Forward);

main :: () {
    args := get_command_line_arguments();

    if args.count == 1 {
        print("Usage: % *number_of_pages*\n", args[0]);
        return;
    }

    //cpu_timer_freq := estimate_cpu_frequency(500);
    initialize_os_metrics();

    page_size := get_page_size();
    //print("Page size: %\n", page_size);

    page_count, success := parse_int(*args[1]);
    if !success {
        print("Please input a number as the first parameter.\n");
        return;
    }

    allocation_size := page_size * page_count;

    Decomposed_Pointer :: struct {
        table_4_index  : u16;
        table_3_index  : u16;
        table_2_index  : u16;
        table_1_index  : u16;
        physical_offset: u16;
    }
    decompose_ptr :: inline (ptr: *void) -> Decomposed_Pointer {
        using result: Decomposed_Pointer;
        p := cast(u64) ptr;

        physical_offset = xx ((p >>  0) & 0xFFF);
        table_1_index   = xx ((p >> 12) & 0x1FF);
        table_2_index   = xx ((p >> 21) & 0x1FF);
        table_3_index   = xx ((p >> 30) & 0x1FF);
        table_4_index   = xx ((p >> 39) & 0x1FF);

        return result;
    }

    #if INSPECT_ADDRESSES
        print("Mem Table 4 idx, Mem Table 3 idx, Mem Table 2 idx, Mem Table 1 idx, Mem physical offset, Touch Count, Fault Count, Extra Faults\n");
    else
        print("Touch Count, Fault Count, Extra Faults\n");
        
    #if TYPE == .Forward { // forwards linear touch
        for page_touch_count: 0..page_count-1 {
            memory := VirtualAlloc(xx 0, xx allocation_size, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE);
            defer VirtualFree(memory, 0, MEM_RELEASE);
            assert(memory != null);

            start_fault_count := read_os_page_fault_count();

            buffer: []u8;
            buffer.data  = xx memory;
            buffer.count = page_size * page_touch_count;
            for *buffer {
                it.* = xx,no_check it_index;
            }
            end_fault_count := read_os_page_fault_count();

            fault_count := end_fault_count - start_fault_count;

            #if INSPECT_ADDRESSES {
                using page_ptr := decompose_ptr(buffer.data + buffer.count);

                BASE :: 2;
                print("%, %, %, %, %,  %, %, %,\n", FormatInt.{value = table_4_index, base = BASE},
                    FormatInt.{value = table_3_index, base = BASE}, FormatInt.{value = table_2_index,   base = BASE},
                    FormatInt.{value = table_1_index, base = BASE}, FormatInt.{value = physical_offset, base = BASE},
                    page_touch_count, fault_count, fault_count - (xx page_touch_count));
            }
            else {
                print("%, %, %,\n", page_touch_count, fault_count, fault_count - (xx page_touch_count));
            }
        }
    }
    else #if TYPE == .Backward { // backwards linear touch
        for page_touch_count: 0..page_count-1 {
            memory := VirtualAlloc(xx 0, xx allocation_size, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE);
            defer VirtualFree(memory, 0, MEM_RELEASE);
            assert(memory != null);

            start_fault_count := read_os_page_fault_count();

            buffer: []u8;
            buffer.count = page_size * page_touch_count;
            buffer.data  = xx memory;
            buffer.data += allocation_size - buffer.count;
            for < *buffer {
                it.* = xx,no_check it_index;
            }
            end_fault_count := read_os_page_fault_count();

            fault_count := end_fault_count - start_fault_count;

            print("%, %, %, %,\n", page_count, page_touch_count, fault_count, fault_count - (xx page_touch_count));
        }
    }
    else #if TYPE == .Forward_Skipping {
        for page_touch_count: 0..page_count-1 {
            memory := VirtualAlloc(xx 0, xx allocation_size, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE);
            defer VirtualFree(memory, 0, MEM_RELEASE);
            assert(memory != null);

            start_fault_count := read_os_page_fault_count();

            buffer: []u8;
            buffer.data  = xx memory;
            buffer.count = page_size * page_touch_count;

            op         : enum { Idle; Write; } = .Write;
            op_counter := 0;
            for *buffer {
                if op == .Idle {
                    if op_counter == SKIP_IDLE {
                        op = .Write;
                        op_counter = 0;
                    }
                }

                if op == .Write {
                    if op_counter == SKIP_WRITE {
                        op = .Idle;
                        op_counter = 0;
                        continue;
                    }
                    it.* = xx,no_check it_index;
                }

                op_counter += 1;
            }
            end_fault_count := read_os_page_fault_count();

            fault_count := end_fault_count - start_fault_count;

            print("%, %, %, %,\n", page_count, page_touch_count, fault_count, fault_count - (xx page_touch_count));
        }
    }
}

write_page :: (address: *void, page_size: int) #expand {
    buffer : []u8;
    buffer.data  = cast(*u8)address;
    buffer.count = page_size;

    for *buffer {
        it.* = 0;
    }
}

#import "Basic";
#import "Command_Line";
#import "String";

#run {
    #import "Compiler";

    set_build_options_dc(.{output_path = "build"});
}

#if OS == .WINDOWS {
get_page_size :: () -> int {
    info: SYSTEM_INFO;
    GetSystemInfo(*info);

    return info.dwPageSize;
}
} // OS == .WINDOWS
