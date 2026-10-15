#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <inttypes.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "flutter_embedder.h"

typedef struct {
  FlutterTask task;
  uint64_t target_time_nanos;
} PendingTask;

// The engine posts platform tasks that only the embedder can run; without a
// platform task runner that the main thread drains, the first frame never
// arrives.
typedef struct {
  pthread_cond_t condition;
  pthread_mutex_t mutex;
  pthread_t platform_thread;
  PendingTask* tasks;
  size_t task_count;
  size_t task_capacity;
  bool frame_received;
  size_t width;
  size_t height;
  uint64_t hash;
} ProbeState;

typedef FlutterEngineResult (*GetProcAddresses)(FlutterEngineProcTable* table);

static uint64_t monotonic_nanos(void) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (uint64_t)now.tv_sec * UINT64_C(1000000000) + (uint64_t)now.tv_nsec;
}

static uint64_t hash_surface(const uint8_t* pixels, size_t size) {
  uint64_t hash = UINT64_C(1469598103934665603);
  for (size_t index = 0; index < size; ++index) {
    hash ^= pixels[index];
    hash *= UINT64_C(1099511628211);
  }
  return hash;
}

static bool present_surface(void* user_data,
                            const void* allocation,
                            size_t row_bytes,
                            size_t height) {
  if (allocation == NULL || row_bytes == 0 || height == 0) {
    return false;
  }

  ProbeState* state = user_data;
  const uint8_t* pixels = allocation;
  const uint64_t hash = hash_surface(pixels, row_bytes * height);

  pthread_mutex_lock(&state->mutex);
  if (!state->frame_received) {
    state->frame_received = true;
    state->width = row_bytes / 4;
    state->height = height;
    state->hash = hash;
    pthread_cond_signal(&state->condition);
  }
  pthread_mutex_unlock(&state->mutex);
  return true;
}

static bool runs_on_platform_thread(void* user_data) {
  ProbeState* state = user_data;
  return pthread_equal(pthread_self(), state->platform_thread);
}

static void post_platform_task(FlutterTask task, uint64_t target_time_nanos, void* user_data) {
  ProbeState* state = user_data;
  pthread_mutex_lock(&state->mutex);
  if (state->task_count == state->task_capacity) {
    const size_t capacity = state->task_capacity == 0 ? 64 : state->task_capacity * 2;
    PendingTask* tasks = realloc(state->tasks, capacity * sizeof(PendingTask));
    if (tasks == NULL) {
      pthread_mutex_unlock(&state->mutex);
      fprintf(stderr, "post_task_callback failed: out of memory\n");
      abort();
    }
    state->tasks = tasks;
    state->task_capacity = capacity;
  }
  state->tasks[state->task_count++] = (PendingTask){task, target_time_nanos};
  pthread_cond_signal(&state->condition);
  pthread_mutex_unlock(&state->mutex);
}

static size_t earliest_task_index(const ProbeState* state) {
  size_t earliest = 0;
  for (size_t index = 1; index < state->task_count; ++index) {
    if (state->tasks[index].target_time_nanos < state->tasks[earliest].target_time_nanos) {
      earliest = index;
    }
  }
  return earliest;
}

static struct timespec timespec_from_nanos(uint64_t nanos) {
  return (struct timespec){
      .tv_sec = (time_t)(nanos / UINT64_C(1000000000)),
      .tv_nsec = (long)(nanos % UINT64_C(1000000000)),
  };
}

static const char* result_name(FlutterEngineResult result) {
  switch (result) {
    case kSuccess:
      return "kSuccess";
    case kInvalidLibraryVersion:
      return "kInvalidLibraryVersion";
    case kInvalidArguments:
      return "kInvalidArguments";
    case kInternalInconsistency:
      return "kInternalInconsistency";
  }
  return "unknown";
}

static int fail_result(const char* operation, FlutterEngineResult result) {
  fprintf(stderr, "%s failed: %s (%d)\n", operation, result_name(result), result);
  return 1;
}

static int fail_message(const char* operation, const char* message) {
  fprintf(stderr, "%s failed: %s\n", operation, message);
  return 1;
}

static uint64_t frame_timeout_nanos(void) {
  // JIT under user-mode emulation is slow: allow overriding the wait.
  const char* timeout_text = getenv("PROBE_TIMEOUT_SECONDS");
  const uint64_t seconds = timeout_text != NULL ? strtoull(timeout_text, NULL, 10) : 120;
  return seconds * UINT64_C(1000000000);
}

// Runs due platform tasks on this (the platform) thread until the first frame
// is presented or the deadline passes.
static int run_platform_tasks_until_frame(const FlutterEngineProcTable* table,
                                          FlutterEngine engine,
                                          ProbeState* state) {
  const uint64_t deadline = monotonic_nanos() + frame_timeout_nanos();

  pthread_mutex_lock(&state->mutex);
  while (!state->frame_received) {
    const uint64_t now = monotonic_nanos();
    if (now >= deadline) {
      pthread_mutex_unlock(&state->mutex);
      return fail_message("surface_present_callback", "timed out waiting for the first frame");
    }

    uint64_t wake_time = deadline;
    if (state->task_count > 0) {
      const size_t index = earliest_task_index(state);
      const PendingTask due = state->tasks[index];
      if (due.target_time_nanos <= now) {
        state->tasks[index] = state->tasks[--state->task_count];
        pthread_mutex_unlock(&state->mutex);
        const FlutterEngineResult result = table->RunTask(engine, &due.task);
        if (result != kSuccess) {
          return fail_result("FlutterEngineRunTask", result);
        }
        pthread_mutex_lock(&state->mutex);
        continue;
      }
      if (due.target_time_nanos < wake_time) {
        wake_time = due.target_time_nanos;
      }
    }

    const struct timespec wake = timespec_from_nanos(wake_time);
    const int wait_result = pthread_cond_timedwait(&state->condition, &state->mutex, &wake);
    if (wait_result != 0 && wait_result != ETIMEDOUT) {
      pthread_mutex_unlock(&state->mutex);
      return fail_message("pthread_cond_timedwait", strerror(wait_result));
    }
  }
  pthread_mutex_unlock(&state->mutex);
  return 0;
}

static int init_probe_state(ProbeState* state) {
  memset(state, 0, sizeof(*state));
  pthread_condattr_t attributes;
  if (pthread_condattr_init(&attributes) != 0 ||
      pthread_condattr_setclock(&attributes, CLOCK_MONOTONIC) != 0 ||
      pthread_cond_init(&state->condition, &attributes) != 0) {
    return fail_message("pthread_cond_init", "could not create a monotonic condition");
  }
  pthread_condattr_destroy(&attributes);
  pthread_mutex_init(&state->mutex, NULL);
  state->platform_thread = pthread_self();
  return 0;
}

static void destroy_probe_state(ProbeState* state) {
  free(state->tasks);
  pthread_cond_destroy(&state->condition);
  pthread_mutex_destroy(&state->mutex);
}

int main(int argc, char** argv) {
  if (argc != 4) {
    fprintf(stderr, "usage: %s <libflutter_engine.so> <flutter_assets> <icudtl.dat>\n", argv[0]);
    return 2;
  }

  void* library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (library == NULL) {
    return fail_message("dlopen", dlerror());
  }

  GetProcAddresses get_proc_addresses = NULL;
  *(void**)(&get_proc_addresses) = dlsym(library, "FlutterEngineGetProcAddresses");
  if (get_proc_addresses == NULL) {
    const char* error = dlerror();
    const int result = fail_message("dlsym", error == NULL ? "symbol not found" : error);
    dlclose(library);
    return result;
  }

  ProbeState state;
  if (init_probe_state(&state) != 0) {
    dlclose(library);
    return 1;
  }
  FlutterEngineProcTable table;
  memset(&table, 0, sizeof(table));
  table.struct_size = sizeof(table);
  FlutterEngineResult result = get_proc_addresses(&table);
  if (result != kSuccess) {
    const int failure = fail_result("FlutterEngineGetProcAddresses", result);
    dlclose(library);
    return failure;
  }

  FlutterRendererConfig renderer_config;
  memset(&renderer_config, 0, sizeof(renderer_config));
  renderer_config.type = kSoftware;
  renderer_config.software.struct_size = sizeof(renderer_config.software);
  renderer_config.software.surface_present_callback = present_surface;

  FlutterTaskRunnerDescription platform_runner;
  memset(&platform_runner, 0, sizeof(platform_runner));
  platform_runner.struct_size = sizeof(platform_runner);
  platform_runner.user_data = &state;
  platform_runner.runs_task_on_current_thread_callback = runs_on_platform_thread;
  platform_runner.post_task_callback = post_platform_task;
  platform_runner.identifier = 1;

  FlutterCustomTaskRunners task_runners;
  memset(&task_runners, 0, sizeof(task_runners));
  task_runners.struct_size = sizeof(task_runners);
  task_runners.platform_task_runner = &platform_runner;

  FlutterProjectArgs project_args;
  memset(&project_args, 0, sizeof(project_args));
  project_args.struct_size = sizeof(project_args);
  project_args.assets_path = argv[2];
  project_args.icu_data_path = argv[3];
  project_args.custom_task_runners = &task_runners;
  project_args.shutdown_dart_vm_when_done = true;

  FlutterEngine engine = NULL;
  result = table.Initialize(FLUTTER_ENGINE_VERSION, &renderer_config, &project_args, &state, &engine);
  if (result != kSuccess) {
    const int failure = fail_result("FlutterEngineInitialize", result);
    dlclose(library);
    return failure;
  }
  if (engine == NULL) {
    const int failure = fail_message("FlutterEngineInitialize", "returned a null engine");
    dlclose(library);
    return failure;
  }

  result = table.RunInitialized(engine);
  if (result != kSuccess) {
    table.Shutdown(engine);
    const int failure = fail_result("FlutterEngineRunInitialized", result);
    dlclose(library);
    return failure;
  }

  FlutterWindowMetricsEvent metrics;
  memset(&metrics, 0, sizeof(metrics));
  metrics.struct_size = sizeof(metrics);
  metrics.width = 320;
  metrics.height = 240;
  metrics.pixel_ratio = 1.0;
  metrics.view_id = 0;
  result = table.SendWindowMetricsEvent(engine, &metrics);
  if (result != kSuccess) {
    table.Shutdown(engine);
    const int failure = fail_result("FlutterEngineSendWindowMetricsEvent", result);
    dlclose(library);
    return failure;
  }

  result = table.ScheduleFrame(engine);
  if (result != kSuccess) {
    table.Shutdown(engine);
    const int failure = fail_result("FlutterEngineScheduleFrame", result);
    dlclose(library);
    return failure;
  }

  const int wait_result = run_platform_tasks_until_frame(&table, engine, &state);
  if (wait_result != 0) {
    table.Shutdown(engine);
    dlclose(library);
    return wait_result;
  }

  printf("frame %zux%zu hash=%016" PRIx64 "\n", state.width, state.height, state.hash);

  result = table.Shutdown(engine);
  if (result != kSuccess) {
    const int failure = fail_result("FlutterEngineShutdown", result);
    dlclose(library);
    return failure;
  }

  printf("ok\n");
  destroy_probe_state(&state);
  dlclose(library);
  return 0;
}
