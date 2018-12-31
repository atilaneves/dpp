#include "s_tl_strin_g.hpp"
#include <string>


size_t getStringSize(void* bytes)
{
	void** bytesPtr = reinterpret_cast<void**>(bytes);
	std::string* p = reinterpret_cast<std::string*>(bytesPtr);
	auto size = p->size();
	return size;
}

void printString(void* bytes)
{
	void** bytesPtr = reinterpret_cast<void**>(bytes);
	std::string* p = reinterpret_cast<std::string*>(bytesPtr);
	auto cs = p->c_str();
	printf("string: %s",cs);
}

const char* getStringData(void* bytes)
{
	void** bytesPtr = reinterpret_cast<void**>(bytes);
	std::string* p = reinterpret_cast<std::string*>(bytesPtr);
	return  p->data();
}
void createString(void* ptr, char* data, size_t size)
{
	void** bytesPtr = reinterpret_cast<void**>(ptr);
	std::string* v = reinterpret_cast<std::string*>(bytesPtr);
	*v = std::string(data,size);
}
