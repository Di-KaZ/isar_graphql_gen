import 'package:isar_graphql/isar_graphql.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import "package:gql/language.dart" as lang;
import "package:gql/ast.dart" as ast;
import "package:gql/schema.dart" as gql_schema;
import "package:gql/operation.dart" as gql_operation;
import "package:isar_graphql/src/isar_collection_visitor.dart";
import "package:isar_graphql/src/types_and_fragment_visitor.dart";

final ast.DocumentNode doc = lang.parseString(
  """
  type A { id: String!, date: DateTime! }
  type B { id: String!, deep_nested_relation: [A!]! }
  type C { id: String! }
  type D { id: String!, coca: Float, nested_relation: B! }
  type E { id: String!, name: String!, shit: Int, relation: D! }
  
  # fragment Test on A {
  #   id
  # 
  # fragment Ahem on D {
  #   id
  # }

  fragment SpreadingZebi on E {
    id
    name
  }

  # !collection
  fragment Zebi on E {
    ...SpreadingZebi
    shit
    relation {
      id
      nested_relation {
        id
        deep_nested_relation {
          id
        }
      }
    }
  }
  """,
);

void main() {
  final v = TypeAndFragmentVisitor();
  doc.accept(v);
  for (final entry in v.fragments.entries) {
    final frag = entry.value;
    // get the line before fragment

    // final lineBeforeFrag = file!.getLine(frag.name.span!.start.line - 2);
    final ctx =
        CollectionContext(frag, v.types[frag.typeCondition.on.name.value]!);
    final isarVisitor = IsarCollectionVisitor(v.types, v.fragments, ctx);

    frag.accept(isarVisitor);

    final emitter = DartEmitter();
    for (final embededCtx in ctx.embeddeds) {
      print(DartFormatter()
          .format('${embededCtx.builder.build().accept(emitter)}'));
    }
    print(DartFormatter().format('${ctx.builder.build().accept(emitter)}'));
  }
}
