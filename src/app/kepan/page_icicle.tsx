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
    fetch('/小止观.opml')
      .then((response) => response.text())
      .then((data) => setOpmlData(data))
      .catch((error) => console.error('Error fetching OPML:', error));
  }, []);

  useEffect(() => {
    if (opmlData && ref.current) {
      // Parse OPML data using DOMParser
      const parsedData = parseOPML(opmlData);

      // Convert parsed data to hierarchy and skip root node with 'No Name'
      const hierarchyData = convertToHierarchy(parsedData);

      // Draw the icicle chart
      drawIcicleChart(hierarchyData);
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

  const drawIcicleChart = (data: HierarchyNode) => {
    const width = 800;

    // Compute the layout.
    const hierarchy = d3
      .hierarchy<HierarchyNode>(data)
      .sum((d) => d.value || 0)
      .sort(
        (a, b) => b.height - a.height || (b.value || 0) - (a.value || 0)
      );

    // Calculate dynamic height based on the number of nodes
    const nodeHeight = 24; // Adjust this value as needed
    const height = Math.max(600, hierarchy.leaves().length * nodeHeight);

    const root = d3.partition<HierarchyNode>().size([height, width])(hierarchy);

    // Create the SVG container.
    const svg = d3
      .select(ref.current)
      .attr('viewBox', `0 0 ${width} ${height}`)
      .attr('width', width)
      .attr('height', height)
      .style('font', '10px sans-serif');

    svg.selectAll('*').remove(); // Clear previous content

    // Create the color scale based on the first level of nodes
    const firstLevelNodes = root.children || [];
    const color = d3
      .scaleOrdinal<string>()
      .domain(firstLevelNodes.map((d) => d.data.name))
      .range(d3.schemeCategory10);

    // Append cells.
    type NodeType = d3.HierarchyRectangularNode<HierarchyNode> & {
      target?: {
        x0: number;
        x1: number;
        y0: number;
        y1: number;
      };
    };

    const cell = svg
      .selectAll<SVGGElement, NodeType>('g')
      .data(root.descendants() as NodeType[])
      .join('g')
      .attr('transform', (d) => `translate(${d.y0},${d.x0})`);

    const rect = cell
      .append('rect')
      .attr('width', (d) => d.y1 - d.y0 - 1)
      .attr('height', (d) => rectHeight(d))
      .attr('fill-opacity', 0.6)
      .attr('fill', (d) => {
        if (!d.parent) return '#ccc'; // For the new root node
        let current = d;
        while (current.depth > 1) current = current.parent!;
        return color(current.data.name);
      })
      .style('cursor', 'pointer')
      .on('click', clicked);

    // Update text wrapping here
    const text = cell
      .append('text')
      .style('user-select', 'none')
      .attr('pointer-events', 'none')
      .attr('x', 4)
      .attr('y', (d) => (rectHeight(d) / 2) - 4);

    text.each(function (d) {
      const node = d3.select(this);
      const rectWidth = d.y1 - d.y0 - 8; // Adjusted rectangle width
      const words = d.data.name.split(/\s+/).reverse();
      let word: string | undefined;
      let line: string[] = [];
      const lineHeight = 10; // Adjust line height as needed
      let tspan = node
        .append('tspan')
        .attr('x', 4)
        .attr('dy', 0);

      while ((word = words.pop())) {
        line.push(word);
        tspan.text(line.join(' '));
        if (
          (tspan.node() as SVGTextContentElement).getComputedTextLength() >
          rectWidth
        ) {
          line.pop();
          tspan.text(line.join(' '));
          line = [word];
          tspan = node
            .append('tspan')
            .attr('x', 4)
            .attr('dy', `${lineHeight}px`)
            .text(word);
        }
      }

      // Adjust the first tspan to vertically center the text block
      const nodeElement = node.node();
      if (nodeElement) {
        const totalTextHeight = nodeElement.getBBox().height;
        node.attr('y', (d) => (rectHeight(d) - totalTextHeight) / 2 + lineHeight);
      }
    });

    cell
      .append('title')
      .text((d) =>
        `${d
          .ancestors()
          .map((d) => d.data.name)
          .reverse()
          .join('/')}\n${d.value || 0}`
      );

    // On click, change the focus and transitions it into view.
    let focus = root;
    function clicked(event: any, p: NodeType) {
      focus = focus === p ? p.parent || root : p;

      root.each((d) => {
        const node = d as NodeType;
        node.target = {
          x0: ((node.x0 - focus.x0) / (focus.x1 - focus.x0)) * height,
          x1: ((node.x1 - focus.x0) / (focus.x1 - focus.x0)) * height,
          y0: node.y0 - focus.y0,
          y1: node.y1 - focus.y0,
        };
      });

      const t = cell
        .transition()
        .duration(750)
        .attr('transform', (d) => `translate(${d.target!.y0},${d.target!.x0})`);

      rect
        .transition(t)
        .attr('width', (d) => d.target!.y1 - d.target!.y0 - 1)
        .attr('height', (d) => rectHeight(d.target!));

      text
        .transition(t)
        .attr('fill-opacity', (d) => +labelVisible(d.target!))
        .attr('y', (d) => (rectHeight(d.target!) / 2) - 4);

      // Update text wrapping during zoom with transition
      text.each(function (d) {
        const node = d3.select(this);
        const rectWidth = d.target!.y1 - d.target!.y0 - 8; // Adjusted rectangle width
        const words = d.data.name.split(/\s+/).reverse();
        let word: string | undefined;
        let line: string[] = [];
        const lineHeight = 10; // Adjust line height as needed
        let tspan = node
          .selectAll('tspan')
          .data(words)
          .join('tspan')
          .attr('x', 4)
          .attr('dy', 0);

        while ((word = words.pop())) {
          line.push(word);
          tspan.text(line.join(' '));
          if (
            (tspan.node() as SVGTextContentElement).getComputedTextLength() >
            rectWidth
          ) {
            line.pop();
            tspan.text(line.join(' '));
            line = [word];
            tspan = node
              .append('tspan')
              .attr('x', 4)
              .attr('dy', `${lineHeight}px`)
              .text(word);
          }
        }

        // Adjust the first tspan to vertically center the text block
        const nodeElement = node.node();
        if (nodeElement) {
          const totalTextHeight = nodeElement.getBBox().height;
          node.transition(t)
            .attr('y', (d) => (rectHeight(d.target!) - totalTextHeight) / 2 + lineHeight);
        }
      });
    }

    function rectHeight(d: any) {
      return d.x1 - d.x0 - Math.min(1, (d.x1 - d.x0) / 2);
    }

    function labelVisible(d: any) {
      return d.y1 <= width && d.y0 >= 0 && d.x1 - d.x0 > 16;
    }
  };

  return (
    <div>
      <Header />
      <div className="flex flex-col items-center min-h-screen p-8 pb-8 gap-8">
        <h1>OPML to Zoomable Icicle Chart</h1>
        {opmlData ? (
          <div
            style={{ width: '800px', overflowY: 'auto' }}
          >
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
