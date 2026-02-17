import React from 'react';
import { Book, Cpu, Terminal, Layers, Code, Zap, Globe, Database, Package, Map } from 'lucide-react';

// Import Pages
import { IntroPage } from './pages/IntroPage';
import { ArchitecturePage } from './pages/ArchitecturePage';
import { ApiReferencePage } from './pages/ApiReferencePage';
import { QuickStartPage } from './pages/QuickStartPage';
import { TraceEnginePage } from './pages/TraceEnginePage';
import { SchedulerModulePage } from './pages/SchedulerModulePage';
import { ShellMakerDocs } from './pages/ShellMakerDocs';
import { PersistenceDocs } from './pages/PersistenceDocs';
import { CodeTracerDocs } from './pages/CodeTracerDocs';
import { PackagesDocs } from './pages/PackagesDocs';
import { SitemapPage } from './pages/SitemapPage';

export type DocRoute = {
    id: string;
    title: string;
    path: string;
    icon?: React.ReactNode;
    component: React.ReactNode;
    description?: string;
};

export type DocSection = {
    title: string;
    items: DocRoute[];
};

export const DOCS_NAVIGATION: DocSection[] = [
    {
        title: "Getting Started",
        items: [
            {
                id: "intro",
                title: "Introduction",
                path: "/docs",
                icon: <Book size={16} />,
                component: <IntroPage />,
                description: "Overview of the OKernel Platform"
            },
            {
                id: "quickstart",
                title: "Quick Start",
                path: "/docs/quickstart",
                icon: <Zap size={16} />,
                component: <QuickStartPage />,
                description: "Get up and running in 5 minutes"
            },
            {
                id: "packages",
                title: "Packages",
                path: "/docs/packages",
                icon: <Package size={16} />,
                component: <PackagesDocs />,
                description: "Install OKernel CLI tools locally"
            },
            {
                id: "sitemap",
                title: "Sitemap",
                path: "/docs/sitemap",
                icon: <Map size={16} />,
                component: <SitemapPage />,
                description: "Complete website navigation map"
            }
        ]
    },
    {
        title: "Architecture",
        items: [
            {
                id: "arch-overview",
                title: "System Design",
                path: "/docs/architecture",
                icon: <Globe size={16} />,
                component: <ArchitecturePage />,
                description: "High-level overview of the SysCore Engine"
            },
            {
                id: "arch-tracing",
                title: "Trace Engine",
                path: "/docs/architecture/tracing",
                icon: <Layers size={16} />,
                component: <TraceEnginePage />,
                description: "How Python execution is intercepted"
            },
            {
                id: "arch-sympathy",
                title: "Code Tracer",
                path: "/docs/architecture/sympathy",
                icon: <Zap size={16} />,
                component: <CodeTracerDocs />,
                description: "Machine Sympathy & Hardware Inspector"
            }
        ]
    },
    {
        title: "Modules",
        items: [
            {
                id: "module-scheduler",
                title: "CPU Scheduler",
                path: "/docs/modules/scheduler",
                icon: <Cpu size={16} />,
                component: <SchedulerModulePage />,
                description: "Process scheduling simulation"
            },
            {
                id: "module-shell",
                title: "Shell Maker",
                path: "/docs/modules/shell",
                icon: <Terminal size={16} />,
                component: <ShellMakerDocs />,
                description: "Custom Shell implementation"
            }
        ]
    },
    {
        title: "API Reference",
        items: [
            {
                id: "api-syscore",
                title: "SysCore API",
                path: "/docs/api/syscore",
                icon: <Code size={16} />,
                component: <ApiReferencePage />,
                description: "Kernel system calls and utilities"
            },
            {
                id: "api-persistence",
                title: "Persistence",
                path: "/docs/api/persistence",
                icon: <Database size={16} />,
                component: <PersistenceDocs />,
                description: "Data storage and session management"
            }
        ]
    }
];

export const getDocRoute = (path: string) => {
    for (const section of DOCS_NAVIGATION) {
        for (const item of section.items) {
            if (item.path === path) return item;
        }
    }
    return null;
};
