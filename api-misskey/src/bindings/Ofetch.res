// Ofetch.res - ReScript bindings for ofetch
// Auto JSON parsing, error handling, baseURL, retries, timeouts

type fetchOptions = {
  baseURL?: string,
  method?: string,
  body?: JSON.t,
  headers?: dict<string>,
  retry?: int,
  retryDelay?: int,
  timeout?: int,
}

@module("ofetch") external ofetch: (string, fetchOptions) => promise<JSON.t> = "ofetch"
