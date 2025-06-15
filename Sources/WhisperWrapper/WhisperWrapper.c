//
//  WhisperWrapper.c
//  QuickTranscribe
//
//  Simple C wrapper for whisper.cpp functions
//

#include "WhisperWrapper.h"
#include "whisper.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct whisper_context * whisper_wrapper_init_from_file(const char * path_model) {
    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true; // Enable Metal acceleration on macOS
    
    struct whisper_context * ctx = whisper_init_from_file_with_params(path_model, cparams);
    if (ctx == NULL) {
        printf("whisper_wrapper: failed to initialize context from file '%s'\n", path_model);
        return NULL;
    }
    
    printf("whisper_wrapper: initialized context from file '%s'\n", path_model);
    return ctx;
}

void whisper_wrapper_free(struct whisper_context * ctx) {
    if (ctx != NULL) {
        whisper_free(ctx);
    }
}

int whisper_wrapper_full_transcribe(struct whisper_context * ctx, const float * samples, int n_samples, char * result, int result_size) {
    if (ctx == NULL || samples == NULL || result == NULL || result_size <= 0) {
        return -1;
    }
    
    // Get default parameters
    struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    
    // Configure parameters for English transcription
    wparams.language = "en";
    wparams.translate = false;
    wparams.print_realtime = false;
    wparams.print_progress = false;
    wparams.print_timestamps = false;
    wparams.print_special = false;
    wparams.no_context = true;
    wparams.single_segment = false;
    wparams.suppress_blank = true;
    wparams.suppress_nst = true;
    wparams.temperature = 0.0f;
    wparams.max_initial_ts = 1.0f;
    wparams.length_penalty = -1.0f;
    
    // Use multiple threads but leave 2 cores free
    int n_threads = 4; // Conservative default
    if (n_threads > 8) n_threads = 8;
    wparams.n_threads = n_threads;
    
    // Reset timings
    whisper_reset_timings(ctx);
    
    // Run the transcription
    int ret = whisper_full(ctx, wparams, samples, n_samples);
    if (ret != 0) {
        printf("whisper_wrapper: failed to run whisper_full, error code: %d\n", ret);
        return ret;
    }
    
    // Extract the transcribed text
    const int n_segments = whisper_full_n_segments(ctx);
    if (n_segments == 0) {
        printf("whisper_wrapper: no segments found\n");
        result[0] = '\0';
        return 0;
    }
    
    // Concatenate all segments
    int result_pos = 0;
    for (int i = 0; i < n_segments; ++i) {
        const char * text = whisper_full_get_segment_text(ctx, i);
        if (text != NULL) {
            int text_len = strlen(text);
            if (result_pos + text_len + 1 < result_size) {
                strcpy(result + result_pos, text);
                result_pos += text_len;
            } else {
                printf("whisper_wrapper: result buffer too small\n");
                break;
            }
        }
    }
    
    result[result_pos] = '\0';
    
    // Print timing information
    whisper_print_timings(ctx);
    
    printf("whisper_wrapper: transcription completed, %d segments, result length: %d\n", n_segments, result_pos);
    return 0;
} 