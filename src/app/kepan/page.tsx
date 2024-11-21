"use client";

import React, { useEffect, useState, useCallback } from 'react';
import ReactFlow, {
  ReactFlowProvider,
  Background,
  Controls,
  MiniMap,
  Edge,
  Node,
  Position,
  Handle,
} from 'reactflow';
import 'reactflow/dist/style.css';
import ELK from 'elkjs/lib/elk.bundled.js';
import Header from '../components/Header';

const elk = new ELK();

interface HierarchyNode {
  name: string;
  children?: HierarchyNode[];
}

interface CollapsibleNodeData {
  label: string;
  id: string;
  isExpanded: boolean;
  toggleExpand: (id: string) => void;
}

interface CollapsibleNodeProps {
  data: CollapsibleNodeData;
}

const CollapsibleNode: React.FC<CollapsibleNodeProps> = ({ data }) => {
  const handleToggle = useCallback(() => {
    data.toggleExpand(data.id);
  }, [data]);

  return (
    <div
      className="bg-white rounded shadow p-2 text-center cursor-pointer"
      onClick={handleToggle}
    >
      {data.label} {data.isExpanded ? '[-]' : '[+]'}
      <Handle type="target" position={Position.Left} />
      <Handle type="source" position={Position.Right} />
    </div>
  );
};

const nodeTypes = { collapsible: CollapsibleNode };

const KepanPage: React.FC = () => {
  const [opmlData, setOpmlData] = useState<string | null>(null);
  const [nodes, setNodes] = useState<Node[]>([]);
  const [edges, setEdges] = useState<Edge[]>([]);

  useEffect(() => {
    fetch('/output_example.opml')
      .then((response) => response.text())
      .then((data) => setOpmlData(data))
      .catch((error) => console.error('Error fetching OPML:', error));
  }, []);

  useEffect(() => {
    if (opmlData) {
      const parsedData = parseOPML(opmlData);
      const hierarchyData = convertToHierarchy(parsedData);
      const { nodes: initialNodes, edges: initialEdges } = convertHierarchyToFlow(
        hierarchyData,
        toggleExpand
      );
      applyLayout(initialNodes, initialEdges).then(({ nodes: layoutedNodes, edges: layoutedEdges }) => {
        setNodes(layoutedNodes);
        setEdges(layoutedEdges);
      });
    }
  }, [opmlData]);

  const toggleExpand = useCallback(
    (id: string) => {
      setNodes((nds) =>
        nds.map((node) => {
          if (node.id === id && node.type === 'collapsible') {
            const isExpanded = !node.data.isExpanded;
            return {
              ...node,
              data: {
                ...node.data,
                isExpanded,
              },
            };
          }
          return node;
        })
      );

      // Recompute nodes and edges based on new expansion state
      const updatedNodes = computeVisibleNodes(nodes);
      applyLayout(updatedNodes, edges).then(({ nodes: layoutedNodes }) => {
        setNodes(layoutedNodes);
      });
    },
    [nodes, edges]
  );

  const computeVisibleNodes = (allNodes: Node[]): Node[] => {
    // Implement logic to compute visible nodes based on isExpanded flags
    // For simplicity, assume all nodes are visible
    return allNodes;
  };

  const applyLayout = async (nodes: Node[], edges: Edge[]) => {
    const elkNodes = nodes.map((node) => ({
      id: node.id,
      width: 160,
      height: 50,
    }));

    const elkEdges = edges.map((edge) => ({
      id: edge.id,
      sources: [edge.source],
      targets: [edge.target],
    }));

    const graph = {
      id: 'root',
      layoutOptions: { 'elk.algorithm': 'layered' },
      children: elkNodes,
      edges: elkEdges,
    };

    const layout = await elk.layout(graph);

    const layoutedNodes = nodes.map((node) => {
      const nodeLayout = layout?.children?.find((n) => n.id === node.id);
      return {
        ...node,
        position: {
          x: nodeLayout?.x || 0,
          y: nodeLayout?.y || 0,
        },
        draggable: false, // Lock nodes to their positions
      };
    });

    return { nodes: layoutedNodes, edges };
  };

  return (
    <div>
      <Header />
      <div className="flex flex-col items-center min-h-screen p-8 pb-8 gap-8">
        <h1>OPML to Mind Map</h1>
        {nodes.length > 0 ? (
          <div className="w-full h-[80vh]">
            <ReactFlowProvider>
              <ReactFlow
                nodes={nodes}
                edges={edges}
                nodeTypes={nodeTypes}
                fitView
                defaultEdgeOptions={{ type: 'smoothstep' }}
                attributionPosition="top-right"
              >
                <MiniMap />
                <Controls />
                <Background />
              </ReactFlow>
            </ReactFlowProvider>
          </div>
        ) : (
          <p>Loading...</p>
        )}
      </div>
    </div>
  );
};

const parseOPML = (opmlString: string): Element => {
  const parser = new DOMParser();
  const xmlDoc = parser.parseFromString(opmlString, 'text/xml');
  const body = xmlDoc.getElementsByTagName('body')[0];
  return body;
};

const convertToHierarchy = (body: Element): HierarchyNode => {
  const rootOutlines = Array.from(body.childNodes).filter(
    (node) => node.nodeName === 'outline'
  ) as Element[];

  if (rootOutlines.length === 1) {
    return traverse(rootOutlines[0]);
  }

  return {
    name: 'Root',
    children: rootOutlines.map((outline) => traverse(outline)),
  };
};

const traverse = (node: Element): HierarchyNode => {
  const children: HierarchyNode[] = [];
  node.childNodes.forEach((childNode) => {
    if (childNode.nodeName === 'outline') {
      const element = childNode as Element;
      children.push(traverse(element));
    }
  });
  return {
    name: node.getAttribute('text') || 'No Name',
    children: children.length > 0 ? children : undefined,
  };
};

const convertHierarchyToFlow = (hierarchy: HierarchyNode, toggleExpand: (id: string) => void) => {
  const nodes: Node[] = [];
  const edges: Edge[] = [];
  let idCounter = 0;

  const positionNode = (
    node: HierarchyNode,
    x: number,
    y: number,
    parentId: string | null = null,
    level = 0
  ): string => {
    const nodeId = `node-${idCounter++}`;
    nodes.push({
      id: nodeId,
      type: 'collapsible',
      data: {
        label: node.name,
        id: nodeId,
        isExpanded: true,
        toggleExpand,
      },
      position: { x, y },
    });

    if (parentId) {
      edges.push({
        id: `edge-${parentId}-${nodeId}`,
        source: parentId,
        target: nodeId,
      });
    }

    if (node.children && node.children.length > 0 && nodes.find((n) => n.id === nodeId)?.data.isExpanded) {
      const childCount = node.children.length;
      const offsetX = 300;
      const offsetY = 100;
      const startY = y - ((childCount - 1) * offsetY) / 2;

      node.children.forEach((child, index) => {
        const childX = x + offsetX;
        const childY = startY + index * offsetY;
        positionNode(child, childX, childY, nodeId, level + 1);
      });
    }

    return nodeId;
  };

  positionNode(hierarchy, 0, 0);

  return { nodes, edges };
};

export default KepanPage;
