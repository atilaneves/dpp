/**
   Utility to avoid top-level imports
 */
module dpp2.from;

/**
   Local imports everywhere.
 */
template from(string moduleName) {
    mixin("import from = " ~ moduleName ~ ";");
}
