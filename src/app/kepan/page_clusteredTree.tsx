"use client";

import React, { useEffect, useRef, useState } from 'react';
import Header from '../components/Header';
import * as d3 from 'd3';

interface HierarchyNode {
  name: string;
  children?: HierarchyNode[];
  value?: number;
}

const KepanPage: React.FC = () => {
  const [opmlData, setOpmlData] = useState<string | null>(null);
  const ref = useRef<SVGSVGElement | null>(null);

  useEffect(() => {
    // Fetch OPML data
    fetch('/入菩萨行论.opml')
    //fetch('/output_example.opml')
      .then((response) => response.text())
      .then((data) => setOpmlData(data))
      .catch((error) => console.error('Error fetching OPML:', error));
  }, []);

  useEffect(() => {
    if (opmlData && ref.current) {
      const parsedData = parseOPML(opmlData);
      const hierarchyData = convertToHierarchy(parsedData);
      drawClusteredTree(hierarchyData);
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

  const drawClusteredTree = (data: HierarchyNode) => {
    const width = 1200;

    // Compute the tree layout
    const root = d3.hierarchy(data);

    // Set the dimensions and margins of the diagram
    const dx = 20;
    const dy = width / (root.height + 1);

    // Use d3.cluster() to align end nodes vertically
    const cluster = d3.cluster<HierarchyNode>().nodeSize([dx, dy]);

    // Sort the tree
    root.sort((a, b) => d3.ascending(a.data.name, b.data.name));

    // Compute the new cluster layout.
    cluster(root);

    // Compute the extent of the tree
    let x0 = Infinity;
    let x1 = -x0;
    root.each((d) => {
      if (d.x > x1) x1 = d.x;
      if (d.x < x0) x0 = d.x;
    });

    const adjustedHeight = x1 - x0 + dx * 2;

    // Remove any existing SVG content
    d3.select(ref.current).selectAll('*').remove();

    // Create the SVG container
    const svg = d3
      .select(ref.current)
      .attr('width', width)
      .attr('height', adjustedHeight)
      .attr('viewBox', [-dy / 3, x0 - dx, width, adjustedHeight])
      .style('font', '10px sans-serif')
      .style('user-select', 'none');

    // Add links between nodes
    svg
      .append('g')
      .attr('fill', 'none')
      .attr('stroke', '#555')
      .attr('stroke-opacity', 0.4)
      .attr('stroke-width', 1.5)
      .selectAll('path')
      .data(root.links())
      .join('path')
      .attr(
        'd',
        d3
          .linkHorizontal()
          .x((d: any) => d.y)
          .y((d: any) => d.x)
      );

    // Add nodes
    const node = svg
      .append('g')
      .attr('stroke-linejoin', 'round')
      .attr('stroke-width', 3)
      .selectAll('g')
      .data(root.descendants())
      .join('g')
      .attr('transform', (d) => `translate(${d.y},${d.x})`);

    node
      .append('circle')
      .attr('fill', (d) => (d.children ? '#555' : '#999'))
      .attr('r', 2.5);

    node
      .append('text')
      .attr('dy', '0.31em')
      .attr('x', (d) => (d.children ? -6 : 6))
      .attr('text-anchor', (d) => (d.children ? 'end' : 'start'))
      .text((d) => d.data.name)
      .clone(true)
      .lower()
      .attr('stroke', 'white');

    // Optional: Add interactions or tooltips as needed
  };

  return (
    <div>
      <Header />
      <div style={{ width: '1200px', overflowY: 'auto' }}>
        <svg ref={ref}></svg>
      </div>
    </div>
  );
};

export default KepanPage;
