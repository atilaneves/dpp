#include "boost/variant.hpp"
#include <string>

using Variant = boost::variant<int,std::string,double>;
struct SomeVariant
{
	boost::variant<int,std::string,double> value;
};

template<class T>
void* variantGet(void* v)
{
	Variant* var = reinterpret_cast<Variant*>(v);
	T& val = boost::get<T>(*var);
	return (T*)&val;
}

template<class T>
void variantSet(void* v,void* value)
{
	Variant* var = reinterpret_cast<Variant*>(v);
	T* valuep = reinterpret_cast<T*>(value);
	*var = *valuep;
}

