use std::env;
use std::io;
use std::path::PathBuf;

fn main() -> Result<(), io::Error> {
    println!("cargo:rerun-if-env-changed=FLUTTER_CORE_OUT_DIR");

    let output_directory = env::var_os("FLUTTER_CORE_OUT_DIR").ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            "FLUTTER_CORE_OUT_DIR is required",
        )
    })?;
    let output_directory = PathBuf::from(output_directory);
    println!(
        "cargo:rustc-link-search=native={}",
        output_directory.display()
    );
    println!(
        "cargo:rustc-link-search=native={}",
        output_directory
            .join("obj/flutter/shell/platform/embedder")
            .display()
    );
    println!("cargo:rustc-link-lib=static=flutter_engine_core_smoke_entry");
    println!("cargo:rustc-link-lib=static=flutter_engine_core");
    println!("cargo:rustc-link-lib=dylib=m");
    println!("cargo:rustc-link-lib=dylib=dl");
    println!("cargo:rustc-link-lib=dylib=pthread");

    Ok(())
}
