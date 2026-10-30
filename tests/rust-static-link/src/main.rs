use std::env;
use std::ffi::CString;
use std::process;

unsafe extern "C" {
    fn flutter_core_smoke_run(
        icu_path: *const std::ffi::c_char,
        assets_path: *const std::ffi::c_char,
    ) -> std::ffi::c_int;
}

fn main() {
    let arguments: Vec<String> = env::args().collect();
    if arguments.len() != 3 {
        eprintln!("usage: core-static-link <icu-path> <assets-path>");
        process::exit(2);
    }

    let icu_path = match CString::new(arguments[1].as_str()) {
        Ok(path) => path,
        Err(_) => {
            eprintln!("icu path contains an interior NUL");
            process::exit(2);
        }
    };
    let assets_path = match CString::new(arguments[2].as_str()) {
        Ok(path) => path,
        Err(_) => {
            eprintln!("assets path contains an interior NUL");
            process::exit(2);
        }
    };

    let status = unsafe { flutter_core_smoke_run(icu_path.as_ptr(), assets_path.as_ptr()) };
    process::exit(status);
}
