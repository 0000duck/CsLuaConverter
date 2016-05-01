namespace CsLuaConverter.Providers
{
    using GenericsRegistry;
    using NameProvider;
    using PartialElement;
    using TypeKnowledgeRegistry;
    using TypeProvider;

    public interface IProviders
    {
        ITypeProvider TypeProvider { get; }
        INameProvider NameProvider { get; }
        IGenericsRegistry GenericsRegistry { get; }
        ITypeKnowledgeRegistry TypeKnowledgeRegistry { get; }
        IPartialElementState PartialElementState { get; }
    }
}