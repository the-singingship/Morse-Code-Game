cmake_minimum_required(VERSION 3.13)

set(PICO_SDK_PATH ${CMAKE_SOURCE_DIR}/pico-sdk)

# Pull in SDK (must be before project)
include(pico_sdk_import.cmake)

project(pico_apps C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

set(PICO_APPS_PATH ${PROJECT_SOURCE_DIR})

# Initialize the SDK
set(PICO_ENABLE_PICOTOOL 0)
pico_sdk_init()

include(apps_auto_set_url.cmake)

add_compile_options(-Wall
        -Wno-format
        -Wno-unused-function
        -Wno-maybe-uninitialized
        )

add_subdirectory(assign02)