#include <vector>

void test(char* bytes)
{
	auto p = reinterpret_cast<std::vector<double>*>(&bytes);
}
