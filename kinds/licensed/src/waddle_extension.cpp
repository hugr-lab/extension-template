#define DUCKDB_EXTENSION_MAIN

#include "waddle_extension.hpp"
#include "duckdb.hpp"
#include "duckdb/common/exception.hpp"
#include "duckdb/function/scalar_function.hpp"
#include <duckdb/parser/parsed_data/create_scalar_function_info.hpp>

// OpenSSL linked through vcpkg
#include <openssl/opensslv.h>

// The kista SDK: licences and usage reports (extension-ci-tools/kista/sdk/cpp/README.md)
#include "kista/kista.hpp"

namespace duckdb {

inline void WaddleScalarFun(DataChunk &args, ExpressionState &state, Vector &result) {
	auto &name_vector = args.data[0];
	UnaryExecutor::Execute<string_t, string_t>(name_vector, result, args.size(), [&](string_t name) {
		return StringVector::AddString(result, "...........🦆 " + name.GetString());
	});
}

inline void WaddleOpenSSLVersionScalarFun(DataChunk &args, ExpressionState &state, Vector &result) {
	auto &name_vector = args.data[0];
	UnaryExecutor::Execute<string_t, string_t>(name_vector, result, args.size(), [&](string_t name) {
		return StringVector::AddString(result, "Waddle " + name.GetString() + ", my linked OpenSSL version is " +
		                                           OPENSSL_VERSION_TEXT);
	});
}

// waddle_pro needs a licence: Check() throws unless it is valid or in grace. What a plan allows
// comes from its limits, with a default for no licence; and the extension reports its use to the
// repository it was installed from when it decides to (kista::Usage::Send, SendAsync).
inline void WaddleProScalarFun(DataChunk &args, ExpressionState &state, Vector &result) {
	auto lic = kista::License::Get(state.GetContext(), "waddle");
	lic.Check();
	auto ducks = lic.Limit<int64_t>("ducks", 1);
	auto &name_vector = args.data[0];
	UnaryExecutor::Execute<string_t, string_t>(name_vector, result, args.size(), [&](string_t name) {
		return StringVector::AddString(result, string(ducks, '.') + "🦆 " + name.GetString());
	});
}

static void LoadInternal(ExtensionLoader &loader) {
	// The licence: from waddle.kista-license beside the module, or from the repository waddle was
	// installed from; waddle_license() shows it
	kista::License::Register(loader, "waddle");

	// Register a scalar function
	auto waddle_scalar_function =
	    ScalarFunction("waddle", {LogicalType::VARCHAR}, LogicalType::VARCHAR, WaddleScalarFun);

	loader.RegisterFunction(waddle_scalar_function);

	// Register another scalar function
	auto waddle_openssl_version_scalar_function = ScalarFunction("waddle_openssl_version", {LogicalType::VARCHAR},
	                                                             LogicalType::VARCHAR, WaddleOpenSSLVersionScalarFun);
	loader.RegisterFunction(waddle_openssl_version_scalar_function);

	// A function that needs a licence
	loader.RegisterFunction(
	    ScalarFunction("waddle_pro", {LogicalType::VARCHAR}, LogicalType::VARCHAR, WaddleProScalarFun));
}

void WaddleExtension::Load(ExtensionLoader &loader) {
	LoadInternal(loader);
}
std::string WaddleExtension::Name() {
	return "waddle";
}

std::string WaddleExtension::Version() const {
#ifdef EXT_VERSION_WADDLE
	return EXT_VERSION_WADDLE;
#else
	return "";
#endif
}

} // namespace duckdb

extern "C" {

DUCKDB_CPP_EXTENSION_ENTRY(waddle, loader) {
	duckdb::LoadInternal(loader);
}
}
