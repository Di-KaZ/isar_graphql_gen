import "package:gql/ast.dart";

class TypeAndFragmentVisitor extends RecursiveVisitor {
  Map<String, ObjectTypeDefinitionNode> types = {};
  Map<String, FragmentDefinitionNode> fragments = {};

  @override
  visitObjectTypeDefinitionNode(
    ObjectTypeDefinitionNode node,
  ) {
    types[node.name.value] = node;
    super.visitObjectTypeDefinitionNode(node);
  }

  @override
  void visitFragmentDefinitionNode(FragmentDefinitionNode node) {
    fragments[node.name.value] = node;
    super.visitFragmentDefinitionNode(node);
  }
}
