"use client";

import React, { useEffect, useRef, useState } from 'react';
import * as d3 from 'd3';
import Header from '../components/Header';

interface HierarchyNode {
  name: string;
  children?: HierarchyNode[];
}

const KepanPage: React.FC = () => {
  const [opmlData, setOpmlData] = useState<string | null>(null);
  const [hierarchyData, setHierarchyData] = useState<HierarchyNode | null>(null);
  const svgRef = useRef<SVGSVGElement | null>(null);

  useEffect(() => {
    const fetchOPML = async () => {
      try {
        const response = await fetch('/output_example.opml');
        if (!response.ok) return;
        const data = await response.text();
        setOpmlData(data);
      } catch (error) {
        console.error('Error fetching OPML:', error);
      }
    };
    fetchOPML();
  }, []);

  useEffect(() => {
    if (!opmlData) return;
    const parsedData = parseOPML(opmlData);
    const hierarchy = convertToHierarchy(parsedData);
    setHierarchyData(hierarchy);
  }, [opmlData]);

  useEffect(() => {
    if (!hierarchyData || !svgRef.current) return;

    d3.select(svgRef.current).selectAll('*').remove();

    const width = 1000;

    const svg = d3
      .select(svgRef.current)
      .attr('width', width)
      .attr('class', 'mx-auto');

    const root = d3.hierarchy<HierarchyNode>(hierarchyData);

    const treeLayout = d3
      .tree<HierarchyNode>()
      .nodeSize([50, 150])
      .separation((a, b) => (a.parent === b.parent ? 1 : 1.2));

    treeLayout(root);

    const nodes = root.descendants();
    const minX = d3.min(nodes, (d) => d.x) ?? 0;
    const maxX = d3.max(nodes, (d) => d.x) ?? 0;
    const totalHeight = maxX - minX + 100;

    svg.attr('height', totalHeight);

    const yOffset = -minX + 50;

    svg
      .selectAll('path.link')
      .data(root.links())
      .enter()
      .append('path')
      .attr('class', 'stroke-gray-400 fill-none')
      .attr(
        'd',
        d3
          .linkHorizontal<d3.HierarchyPointNode<HierarchyNode>, d3.HierarchyPointLink<HierarchyNode>>()
          .x((d) => d.y)
          .y((d) => d.x + yOffset)
      );

    const node = svg
      .selectAll('g.node')
      .data(nodes)
      .enter()
      .append('g')
      .attr('transform', (d) => `translate(${d.y},${d.x + yOffset})`);

    node
      .append('circle')
      .attr('class', 'fill-blue-500')
      .attr('r', 6);

    node
      .append('text')
      .attr('class', 'text-sm font-medium')
      .attr('dy', 3)
      .attr('x', (d) => (d.children ? -10 : 10))
      .style('text-anchor', (d) => (d.children ? 'end' : 'start'))
      .text((d) => d.data.name);
  }, [hierarchyData]);

  return (
    <div>
      <Header />
      <div className="flex flex-col items-center min-h-screen p-8 gap-8">
        <h1 className="text-2xl font-bold">OPML Mind Map</h1>
        <svg ref={svgRef}></svg>
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

export default KepanPage;
