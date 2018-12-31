import std.exception:enforce;
struct Opaque(string TypeName,size_t BlobSize)
{
	ubyte[BlobSize] blob;
	alias blob this;
	enum blobSize = BlobSize;
	enum typeName = TypeName;

	this(ubyte[] blob)
	{
		enforce(blob.length == BlobSize);
		this.blob=blob;
	}
}
