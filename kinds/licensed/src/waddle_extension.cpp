#define DUCKDB_EXTENSION_MAIN

#include "waddle_extension.hpp"
#include "duckdb.hpp"
#include "duckdb/common/exception.hpp"
#include "duckdb/function/scalar_function.hpp"
#include "duckdb/planner/expression/bound_function_expression.hpp"
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

// waddle_pro needs a licence. The licence is read when a query binds the function, never per chunk:
// Check() throws unless it is valid or in grace, and Limit() reads what the plan allows, with a
// default for no licence. The extension also reports its use to the repository it was installed
// from when it decides to (kista::Usage::Send, SendAsync).
struct WaddleProData : public FunctionData {
	explicit WaddleProData(int64_t ducks) : ducks(ducks) {
	}
	int64_t ducks;

	unique_ptr<FunctionData> Copy() const override {
		return make_uniq<WaddleProData>(ducks);
	}
	bool Equals(const FunctionData &other) const override {
		return ducks == other.Cast<WaddleProData>().ducks;
	}
};

static unique_ptr<FunctionData> WaddleProBind(BindScalarFunctionInput &input) {
	auto lic = kista::License::Get(input.GetClientContext(), "waddle");
	lic.Check();
	// a licence's limit is the issuer's to set: keep it within what the function can do
	auto ducks = std::min<int64_t>(std::max<int64_t>(lic.Limit<int64_t>("ducks", 1), 1), 16);
	return make_uniq<WaddleProData>(ducks);
}

inline void WaddleProScalarFun(DataChunk &args, ExpressionState &state, Vector &result) {
	auto &data = state.expr.Cast<BoundFunctionExpression>().BindInfo()->Cast<WaddleProData>();
	auto ducks = string(NumericCast<size_t>(data.ducks), '.');
	auto &name_vector = args.data[0];
	UnaryExecutor::Execute<string_t, string_t>(name_vector, result, args.size(), [&](string_t name) {
		return StringVector::AddString(result, ducks + "🦆 " + name.GetString());
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
	    ScalarFunction("waddle_pro", {LogicalType::VARCHAR}, LogicalType::VARCHAR, WaddleProScalarFun, WaddleProBind));
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
