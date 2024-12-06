"use client";

import React, { useEffect, useRef, useState } from 'react';
import Header from '../components/Header';
import * as d3 from 'd3';

interface HierarchyNode {
  name: string;
  children?: HierarchyNode[];
  _children?: HierarchyNode[]; // For storing collapsed children
  value?: number;
}

const KepanPage: React.FC = () => {
  const [opmlData, setOpmlData] = useState<string | null>(null);
  const ref = useRef<SVGSVGElement | null>(null);

  useEffect(() => {
    // Fetch OPML data
    fetch('/小止观.opml')
      .then((response) => response.text())
      .then((data) => setOpmlData(data))
      .catch((error) => console.error('Error fetching OPML:', error));
  }, []);

  useEffect(() => {
    if (opmlData && ref.current) {
      const parsedData = parseOPML(opmlData);
      const hierarchyData = convertToHierarchy(parsedData);
      drawIndentedTree(hierarchyData);
    }
  }, [opmlData]);

  const parseOPML = (opmlString: string): Element => {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(opmlString, 'text/xml');
    const body = xmlDoc.getElementsByTagName('body')[0];
    return body;
  };

  const convertToHierarchy = (body: Element): HierarchyNode => {
    // Skip the root node with 'No Name' and return its children as the new root
    const rootOutlines = Array.from(body.childNodes).filter(
      (node) => node.nodeName === 'outline'
    ) as Element[];

    // If there's only one root outline, use it directly
    if (rootOutlines.length === 1) {
      return traverse(rootOutlines[0]);
    }

    // If there are multiple root outlines, create a root node with these as children
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
      value: children.length === 0 ? 1 : undefined, // Assign value 1 to leaf nodes
    };
  };

  const drawIndentedTree = (data: HierarchyNode) => {
    const format = d3.format(',');
    const nodeSize = 17;

    // Define a custom type to include the index and _children properties
    type HierarchyNodeType = d3.HierarchyNode<HierarchyNode> & {
      index?: number;
      x?: number;
      y?: number;
      _children?: HierarchyNodeType[]; // Add _children property
    };

    // Create the hierarchy and assign an index to each node
    let index = 0;
    const root = d3
      .hierarchy<HierarchyNode>(data)
      .eachBefore((d) => {
        (d as HierarchyNodeType).index = index++;
      }) as HierarchyNodeType;

    // Collapse all nodes initially
    //root.children?.forEach(collapse);

    // Create the SVG container.
    const svg = d3
      .select(ref.current)
      .attr('width', 800)
      .style('font', '12px sans-serif')
      .style('overflow', 'visible');

    svg.selectAll('*').remove(); // Clear previous content

    // Initialize the tree layout
    const gNode = svg.append('g').attr('cursor', 'pointer');

    update(root);

    function update(source: HierarchyNodeType) {
      const paddingX = 20; // Horizontal padding for the root node
      const paddingY = 20; // Vertical padding for the root node

      // Compute the new tree layout.
      const nodes = root.descendants().filter((d) => d.depth >= 0);
      const height = Math.max(500, nodes.length * nodeSize + 100);

      svg.transition().duration(500).attr('height', height);

      let index = -1;
      root.eachBefore((n) => {
        n.x = ++index * nodeSize + paddingY; // Add vertical padding
        n.y = n.depth * 20 + paddingX; // Add horizontal padding
      });

      // Update the nodes...
      const node = gNode.selectAll<SVGGElement, HierarchyNodeType>('g')
        .data(nodes, (d) => d.id || (d.id = ++index));

      // Enter new nodes at the parent's previous position with fade-in effect.
      const nodeEnter = node.enter().append('g')
        .attr('transform', (d) => `translate(${source.y},${source.x})`)
        .style('opacity', 0) // Start with opacity 0 for fade-in effect
        .on('click', (event, d) => {
          if (d.children) {
            d._children = d.children;
            d.children = undefined;
          } else {
            d.children = d._children;
            d._children = undefined;
          }
          update(d);
        });

      nodeEnter.append('circle')
        .attr('r', 2.5)
        .attr('fill', (d) => (d._children ? '#555' : '#999'));

      nodeEnter.append('text')
        .attr('dy', '0.32em')
        .attr('x', 6)
        .text((d) => d.data.name);

      nodeEnter.append('title')
        .text((d) => d.ancestors().reverse().map((d) => d.data.name).join('/'));

      // Transition nodes to their new position with fade-in effect.
      const nodeUpdate = nodeEnter.merge(node as any)
        .transition()
        .duration(500)
        .attr('transform', (d) => `translate(${d.y},${d.x})`)
        .style('opacity', 1); // Transition to full opacity

      nodeUpdate.select('circle')
        .attr('fill', (d) => (d._children ? '#555' : '#999'));

      // Remove exiting nodes with a fade-out effect
      const nodeExit = node.exit()
        .transition()
        .duration(500)
        .attr('transform', (d) => `translate(${source.y},${source.x})`)
        .style('opacity', 0)
        .remove();

      // Update the links...
      const link = svg.selectAll('path')
        .data(root.links(), (d) => (d.target as any).id);

      // Enter new links at the parent's previous position.
      const linkEnter = link.enter().insert('path', 'g')
        .attr('d', (d) => `
          M${d.source.y},${d.source.x}
          V${d.target.x}
          H${d.target.y}
        `)
        .attr('fill', 'none')
        .attr('stroke', '#999');

      // Transition links to their new position.
      linkEnter.merge(link as any)
        .transition()
        .duration(500)
        .attr('d', (d) => `
          M${d.source.y},${d.source.x}
          V${d.target.x}
          H${d.target.y}
        `);

      // Remove exiting links with a fade-out effect
      link.exit()
        .transition()
        .duration(500)
        .attr('d', (d) => `
          M${source.y},${source.x}
          V${source.x}
          H${source.y}
        `)
        .style('opacity', 0)
        .remove();
    }

    function collapse(d: HierarchyNodeType) {
      if (d.children) {
        d._children = d.children;
        d._children.forEach(collapse);
        d.children = undefined;
      }
    }
  };

  return (
    <div>
      <Header />
      <div className="flex flex-col items-center min-h-screen p-8 pb-8 gap-8">
        <h1>OPML to Collapsible Indented Tree</h1>
        {opmlData ? (
          <div style={{ width: '800px', overflowY: 'auto' }}>
            <svg ref={ref}></svg>
          </div>
        ) : (
          <p>Loading...</p>
        )}
      </div>
    </div>
  );
};

export default KepanPage;
