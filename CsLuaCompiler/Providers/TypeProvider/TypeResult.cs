namespace CsLuaCompiler.Providers.TypeProvider
{
    using System;
    using System.Linq;

    public class TypeResult
    {
        public string AdditionalString;
        public Type Type;

        private static string StripGenericsFromType(string name)
        {
            return name.Split('`').First();
        }

        public string ToQuotedString()
        {
            return "'" + this.ToString() + "'";
        }

        public override string ToString()
        {
            var genericStrippedFullName = StripGenericsFromType(this.Type.FullName);
            if (string.IsNullOrEmpty(this.AdditionalString))
            {
                return genericStrippedFullName;
            }

            return genericStrippedFullName + "." + this.AdditionalString;
        }
    }
}