using Microsoft.VisualStudio.LanguageServer.Client;
using Microsoft.VisualStudio.Utilities;
using System.ComponentModel.Composition;

namespace Visual_Oxidation
{
    public class RustContentTypeDefinition
    {
        [Export]
        [Name("rs")]
        [BaseDefinition(CodeRemoteContentDefinition.CodeRemoteContentTypeName)]
        internal static ContentTypeDefinition RsContentTypeDefinition;

        [Export]
        [FileExtension(".rs")]
        [ContentType("rs")]
        internal static FileExtensionToContentTypeDefinition RsFileExtensionDefinition;
    }
}
