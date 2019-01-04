#include <string>

struct ProblemString
{
	std::string s;
};

size_t getStringSize(void* bytes);
void printString(void* bytes);
const char* getStringData(void* bytes);
void createString(void* ptr, char* data, size_t size);
