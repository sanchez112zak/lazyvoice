//
//  WhisperWrapper.h
//  QuickTranscribe
//
//  Simple C wrapper for whisper.cpp functions
//

#ifndef WhisperWrapper_h
#define WhisperWrapper_h

#ifdef __cplusplus
extern "C" {
#endif

// Forward declaration
struct whisper_context;

// Initialize whisper context from model file
struct whisper_context * whisper_wrapper_init_from_file(const char * path_model);

// Free whisper context
void whisper_wrapper_free(struct whisper_context * ctx);

// Perform full transcription
// Returns 0 on success, negative on error
int whisper_wrapper_full_transcribe(struct whisper_context * ctx, 
                                   const float * samples, 
                                   int n_samples, 
                                   char * result, 
                                   int result_size);

#ifdef __cplusplus
}
#endif

#endif /* WhisperWrapper_h */ 