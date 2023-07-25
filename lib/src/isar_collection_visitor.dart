import "package:code_builder/code_builder.dart";
import "package:gql/ast.dart";

const collectionAnnotation = CodeExpression(Code('collection'));
const embeddedAnnotation = CodeExpression(Code('embedded'));
const jsonAnnotation = CodeExpression(Code('JsonSerializable()'));

class CollectionContext {
  FragmentDefinitionNode fragment;
  ObjectTypeDefinitionNode fragmentType;
  ClassBuilder builder = ClassBuilder();
  ConstructorBuilder defaultConstructor = ConstructorBuilder();
  List<EmbeddedContext> embeddeds = [];

  CollectionContext(this.fragment, this.fragmentType);
}

class EmbeddedContext {
  CollectionContext collectionCtx;
  FieldNode node;
  ObjectTypeDefinitionNode type;
  ClassBuilder builder = ClassBuilder();
  ConstructorBuilder defaultConstructor = ConstructorBuilder();

  EmbeddedContext(this.node, this.type, this.collectionCtx);
}

class IsarCollectionVisitor extends RecursiveVisitor {
  final Map<String, ObjectTypeDefinitionNode> schema;
  final Map<String, FragmentDefinitionNode> fragments;

  final CollectionContext ctx;

  IsarCollectionVisitor(this.schema, this.fragments, this.ctx);

  @override
  void visitFragmentSpreadNode(FragmentSpreadNode node) {
    // get the original fragment
    final fragment = fragments[node.name.value]!;
    fragment.visitChildren(IsarCollectionVisitor(schema, fragments, ctx));
  }

  @override
  void visitFragmentDefinitionNode(FragmentDefinitionNode node) {
    ctx.builder.name = 'Collection\$${node.name.value}';
    ctx.builder.annotations.addAll([collectionAnnotation, jsonAnnotation]);
    final schemaType = schema[node.typeCondition.on.name.value];
    if (schemaType == null) {
      throw Exception(
          'type [${node.typeCondition.on.name.value}] does not exist in schema');
    }
    node.visitChildren(IsarCollectionVisitor(schema, fragments, ctx));
    ctx.builder.constructors.add(ctx.defaultConstructor.build());
    ctx.builder.methods.add(
      Method(
        (b) => b
          ..returns = Reference('Map<String, dynamic>')
          ..name = 'toJson'
          ..lambda = true
          ..body = Code('''
        _\$${ctx.builder.name}ToJson(this)
      '''),
      ),
    );
    ctx.builder.fields.add(Field((b) => b
      ..name = 'isar_id'
      ..type = Reference('Id')
      ..assignment = Code('Isar.autoIncrement')));
    ctx.builder.constructors.add(
      Constructor(
        (b) => b
          ..factory = true
          ..name = 'fromJson'
          ..lambda = true
          ..requiredParameters.add(
            Parameter(
              (b) => b
                ..name = 'json'
                ..type = Reference('Map<String, dynamic>'),
            ),
          )
          ..body = Code('''
            _\$${ctx.builder.name}FromJson(json)
          '''),
      ),
    );
  }

  @override
  void visitFieldNode(FieldNode node) {
    final fieldDefinition = ctx.fragmentType.fields
        .firstWhere((element) => element.name.value == node.name.value);
    final field = FieldBuilder();
    field.name = node.name.value;
    field.type = Reference(
      constructDartType(
        fieldDefinition.type,
        node.selectionSet != null ? ctx.builder.name : null,
      ),
    );

    final parameter = Parameter(
      (b) => b
        ..name = field.name!
        ..named = true
        ..toThis = true
        ..required = fieldDefinition.type.isNonNull
        ..build(),
    );

    ctx.defaultConstructor.optionalParameters.add(parameter);
    if (node.selectionSet != null) {
      final typeName = fieldDefinition.type is NamedTypeNode
          ? (fieldDefinition.type as NamedTypeNode).name.value
          : ((fieldDefinition.type as ListTypeNode).type as NamedTypeNode)
              .name
              .value;

      final EmbeddedContext emCtx = EmbeddedContext(
        node,
        schema[typeName]!,
        ctx,
      );

      node.accept(
        IsarEmbeddedVisitor(
          schema,
          emCtx,
          constructDartType(fieldDefinition.type, ctx.builder.name, true),
        ),
      );
      ctx.embeddeds.add(emCtx);
    }
    ctx.builder.fields.add(field.build());
  }
}

class IsarEmbeddedVisitor extends RecursiveVisitor {
  EmbeddedContext ctx;
  final Map<String, ObjectTypeDefinitionNode> schema;
  final String name;

  IsarEmbeddedVisitor(this.schema, this.ctx, this.name);

  @override
  void visitFieldNode(FieldNode node) {
    ctx.builder.annotations.addAll([embeddedAnnotation, jsonAnnotation]);
    ctx.builder.name = name;
    final embededVisitor = IsarEmbeddedFieldVisitor(schema, ctx);
    node.visitChildren(embededVisitor);
    ctx.builder.constructors.add(ctx.defaultConstructor.build());
    ctx.builder.methods.add(
      Method(
        (b) => b
          ..returns = Reference('Map<String, dynamic>')
          ..name = 'toJson'
          ..lambda = true
          ..body = Code('''
        _\$${ctx.builder.name}ToJson(this)
      '''),
      ),
    );
    ctx.builder.constructors.add(
      Constructor(
        (b) => b
          ..factory = true
          ..lambda = true
          ..name = 'fromJson'
          ..requiredParameters.add(
            Parameter(
              (b) => b
                ..name = 'json'
                ..type = Reference('Map<String, dynamic>'),
            ),
          )
          ..body = Code('''
            _\$${ctx.builder.name}FromJson(json)
          '''),
      ),
    );
  }
}

class IsarEmbeddedFieldVisitor extends RecursiveVisitor {
  EmbeddedContext ctx;
  final Map<String, ObjectTypeDefinitionNode> schema;

  IsarEmbeddedFieldVisitor(this.schema, this.ctx);

  @override
  void visitFieldNode(FieldNode node) {
    final field = FieldBuilder();
    final fieldDefinition = ctx.type.fields
        .firstWhere((element) => element.name.value == node.name.value);

    field.name = node.name.value;
    field.type = Reference(
      constructDartType(
        fieldDefinition.type,
        node.selectionSet != null ? ctx.builder.name : null,
      ),
    );

    final parameter = Parameter(
      (b) => b
        ..name = field.name!
        ..named = true
        ..toThis = true
        ..defaultTo = defaultValue(fieldDefinition.type, field.type!.symbol!)
        ..build(),
    );

    ctx.defaultConstructor.optionalParameters.add(parameter);

    if (node.selectionSet != null) {
      final typeName = fieldDefinition.type is NamedTypeNode
          ? (fieldDefinition.type as NamedTypeNode).name.value
          : ((fieldDefinition.type as ListTypeNode).type as NamedTypeNode)
              .name
              .value;

      final EmbeddedContext emCtx = EmbeddedContext(
        node,
        schema[typeName]!,
        ctx.collectionCtx,
      );

      node.accept(
        IsarEmbeddedVisitor(
          schema,
          emCtx,
          constructDartType(fieldDefinition.type, ctx.builder.name, true),
        ),
      );
      ctx.collectionCtx.embeddeds.add(emCtx);
    }
    ctx.builder.fields.add(field.build());
  }
}

String constructDartType(TypeNode type, String? prefix,
    [bool withoutList = false]) {
  if (type is NamedTypeNode) {
    return '${prefix ?? ''}${prefix != null ? '\$' : ''}${dartType(type.name.value)}${type.isNonNull ? '' : '?'}';
  } else if (type is ListTypeNode) {
    if (withoutList) {
      return constructDartType(type.type, prefix);
    }
    return 'List<${constructDartType(type.type, prefix)}>${type.type.isNonNull ? '' : '?'}';
  } else {
    throw Exception('unknown type');
  }
}

String dartType(String type) {
  switch (type) {
    case 'String':
      return 'String';
    case 'Int':
      return 'int';
    case 'Float':
      return 'double';
    case 'Boolean':
      return 'bool';
    case 'uuid':
      return 'String';
  }
  return type;
}

Code defaultValue(TypeNode type, String fullName) {
  if (type is ListTypeNode) {
    return Code("const []");
  }

  switch (fullName) {
    case 'String':
      return Code("''");
    case 'int':
      return Code("0");
    case 'double':
      return Code("0.0");
    case 'bool':
      return Code("false");
    case 'uuid':
      return Code("''");
  }
  return Code("$fullName()");
}

// String
