#include <stddef.h>
#include <stdint.h>
int chagok_inflate(const uint8_t *input, size_t count, uint8_t *output, size_t outputCount);
uint32_t chagok_crc(const uint8_t *input, size_t count);
