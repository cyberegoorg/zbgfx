#include <bx/bx.h>
#include <bx/string.h>

extern "C" {
    int32_t formatTrace(char* buff, uint32_t buff_size, const char* _format, va_list _argList) {
			char* out = buff;
			va_list argListCopy;
			int32_t total = bx::vsnprintf(out, buff_size, _format, _argList);
            return total;
    }
}
