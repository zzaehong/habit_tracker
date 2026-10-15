#include "CZip.h"
#include <zlib.h>
int chagok_inflate(const uint8_t *input, size_t count, uint8_t *output, size_t outputCount) {
    z_stream stream = {0}; stream.next_in = (Bytef *)input; stream.avail_in = (uInt)count; stream.next_out = output; stream.avail_out = (uInt)outputCount;
    if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) return 0;
    int result = inflate(&stream, Z_FINISH);
    int valid = result == Z_STREAM_END && stream.total_out == outputCount && stream.total_in == count;
    inflateEnd(&stream); return valid;
}
uint32_t chagok_crc(const uint8_t *input, size_t count) { return (uint32_t)crc32(0, input, (uInt)count); }
