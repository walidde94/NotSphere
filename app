import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react';

// --- Helper Functions & Constants ---
const debounce = (func, delay) => {
  let timeout;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), delay);
  };
};

const base64ToArrayBuffer = (base64) => {
  const binaryString = window.atob(base64);
  const len = binaryString.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes.buffer;
};

const pcmToWav = (pcmData, sampleRate) => {
  const header = new ArrayBuffer(44);
  const view = new DataView(header);
  const numChannels = 1;
  const bitsPerSample = 16;
  const blockAlign = (numChannels * bitsPerSample) / 8;
  const byteRate = sampleRate * blockAlign;
  const dataSize = pcmData.byteLength;

  view.setUint32(0, 1380533830, false); // "RIFF"
  view.setUint32(4, 36 + dataSize, true);
  view.setUint32(8, 1463899717, false); // "WAVE"
  view.setUint32(12, 1718449184, false); // "fmt "
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, bitsPerSample, true);
  view.setUint32(36, 1684108385, false); // "data"
  view.setUint32(40, dataSize, true);

  const wavBytes = new Uint8Array(44 + dataSize);
  wavBytes.set(new Uint8Array(header), 0);
  wavBytes.set(new Uint8Array(pcmData), 44);

  return new Blob([wavBytes], { type: 'audio/wav' });
};

const formatDate = (dateStr) => {
  if (!dateStr) return '';
  const date = new Date(dateStr);
  const now = new Date();
  const diffTime = Math.abs(now - date);
  const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

  if (diffDays === 0) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
  if (diffDays === 1) {
    return 'Yesterday';
  }
  return date.toLocaleDateString();
};

const AI_ACTIONS = {
  HIGHLIGHT_INSIGHTS: '🔎 Highlight Key Insights',
  SUMMARIZE: 'Summarize',
  ACTION_ITEMS: 'List Action Items',
  BRAINSTORM: 'Brainstorm Ideas',
  IMPROVE: 'Improve Writing',
  FIX_GRAMMAR: 'Fix Spelling & Grammar',
  SHORTER: 'Make Shorter',
  LONGER: 'Make Longer',
  PROFESSIONAL: 'Change Tone to Professional',
  CASUAL: 'Change Tone to Casual',
  EXPLAIN_THIS: 'Explain This',
  GENERATE_QUIZ: 'Generate Quiz',
  GENERATE_FLASHCARDS: '📚 Generate Flashcards',
  CLEANUP_TRANSCRIPT: '✨ Clean Up Transcript',
};

// Editor-only slash commands
const EDITOR_COMMANDS = {
    TODO: 'Todo List',
    H1: 'Heading 1',
    H2: 'Heading 2',
    TEXT_BOX: 'Text Box',
    TABLE: 'Simple Table',
};

const TABLE_DESIGNS = {
    SIMPLE: 'Simple (Grid)',
    HEADER: 'Header Row',
    CLEAN: 'Clean (Lines)',
};

const TEMPLATES = {
    MEETING_AGENDA: {
        name: 'Meeting Agenda',
        prompt: (topic) => `Create a detailed meeting agenda about "${topic}". Include sections for Attendees, Agenda Items with time allocation, Action Items from the previous meeting, and Key Decisions to be made. Pre-fill it with logical example content.`
    },
    BRAINSTORM_SESSION: {
        name: 'Brainstorm Session',
        prompt: (topic) => `Structure a brainstorming session note for "${topic}". Include sections for Objective, Core Questions, a mind map area with initial ideas, and a section for Next Steps. Pre-fill it with creative starting points.`
    },
    TODO_LIST: {
        name: 'Project To-Do List',
        prompt: (topic) => `Generate a comprehensive to-do list for a project called "${topic}". Organize it into phases like 'Planning', 'Execution', and 'Launch' with realistic example tasks under each. Use checklists.`
    }
};

// --- UI Helper Components ---

const Spinner = () => <div className="w-5 h-5 border-2 border-t-primary-bg border-text-tertiary/20 rounded-full animate-spin"></div>;

const ToolbarButton = ({ children, onClick, title, onMouseDown }) => (
    <button
        onMouseDown={onMouseDown || (e => e.preventDefault())} // Prevent focus loss by default
        onClick={onClick}
        title={title}
        className="p-2 rounded-full hover:bg-hover transition-colors text-text-secondary hover:text-text-primary"
    >
        {children}
    </button>
);
const ToolbarSeparator = () => <div className="w-6 h-px bg-border-main my-1 md:w-px md:h-6 md:my-0 md:mx-1"></div>;

// --- SVG Icons ---
const ChevronLeftIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M14 18.4 7.6 12 14 5.6l1.4 1.4-5 5 5 5Z"/></svg>;
const ChevronRightIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M8.6 18.4 10 17l5-5-5-5-1.4 1.4L12.2 12Z"/></svg>;
const PlusIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M11 19v-6H5v-2h6V5h2v6h6v2h-6v6Z"/></svg>;
const FolderIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M4 20q-.825 0-1.412-.587Q2 18.825 2 18V6q0-.825.588-1.413Q3.175 4 4 4h6l2 2h8q.825 0 1.413.587Q22 7.175 22 8v10q0 .825-.587 1.413Q20.825 20 20 20Z"/></svg>;
const FilePlusIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M13 18h-2v-3H8v-2h3v-3h2v3h3v2h-3ZM6 22q-.825 0-1.412-.587Q4 20.825 4 20V4q0-.825.588-1.413Q5.175 2 6 2h8l6 6v12q0 .825-.587 1.413Q18.825 22 18 22Zm7-13V4H6v16h12V9Z"/></svg>;
const SparklesIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M12 21q-1.05 0-1.987-.388-.938-.387-1.688-1.062L12 15.9l3.675 3.675q-.75.675-1.688 1.062Q13.05 21 12 21ZM8.025 17.5 4.35 13.825q-.675-.75-1.062-1.688Q3 11.2 3 10.15q0-1.725.825-3.225 1.25-1 3.125-1 .95 0 1.85.363.9.362 1.65 1.037L12 8.1l1.175-1.775q.75-.675 1.65-1.038.9-.362 1.85-.362 1.875 0 3.125 1 .825 1.5.825 3.225 0 1.05-.388 1.987-.387.938-1.062 1.688L15.975 17.5 12 13.225ZM12 12.125.75 23.375 12 12.125.75 23.375Z"/></svg>;
const TrashIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M7 21q-.825 0-1.412-.587Q5 19.825 5 19V6H4V4h5V3h6v1h5v2h-1v13q0 .825-.587 1.413Q17.825 21 17 21ZM17 6H7v13h10Z"/></svg>;
const BoldIcon = (props) => <svg {...props} className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24"><path d="M8 19h6.35q1.925 0 3.038-1.062 1.112-1.063 1.112-2.688 0-1.275-.788-2.175-.787-.9-2.212-1.225V11.7q1.2-.3 1.9-1.125.7-.825.7-2.025 0-1.425-.975-2.275T14.4 5H8Zm2-2v-5h4.1q.95 0 1.475.525.525.525.525 1.425 0 .9-.525 1.425Q15.05 15 14.1 15Zm0-7v-3h4.3q.825 0 1.263.438.437.437.437 1.112 0 .675-.437 1.112Q14.925 10 14.1 10Z"/></svg>;
const ItalicIcon = (props) => <svg {...props} className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24"><path d="M6 20v-2h3.375l3.4-8H9V8h8v2h-3.375l-3.4 8H15v2Z"/></svg>;
const UnderlineIcon = (props) => <svg {...props} className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24"><path d="M5 21v-2h14v2Zm7-4q-2.075 0-3.538-1.463Q7 14.075 7 12V3h2v9q0 1.25.875 2.125T12 15q1.25 0 2.125-.875T15 12V3h2v9q0 2.075-1.462 3.537Q14.075 17 12 17Z"/></svg>;
const ListIcon = (props) => <svg {...props} className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24"><path d="M3 19v-2h2v2Zm4 0v-2h14v2Zm-4-6v-2h2v2Zm4 0v-2h14v2Zm-4-6V5h2v2Zm4 0V5h14v2Z"/></svg>;
const StrikethroughIcon = (props) => <svg {...props} className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24"><path d="M4 13v-2h16v2ZM9 7V4h6v3Zm-1 9q-1.25 0-2.125-.875T5 14v-1h2v1q0 .425.288.713.287.287.712.287h8q.425 0 .713-.287.287-.288.287-.713v-1h2v1q0 1.25-.875 2.125T16 16Z"/></svg>;
const QuoteIcon = (props) => <svg {...props} className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24"><path d="m15.3 17.3-1.7-2.7V8H7v6.6l-2.3 3.7ZM6.3 17.3 4.6 14.6V8H-2v6.6l-2.3 3.7Z" transform="translate(4 3)"/></svg>;
const CodeIcon = (props) => <svg {...props} className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24"><path d="m9.6 18-1.4-1.4 5.6-5.6-5.6-5.6L9.6 4l7 7Z"/></svg>;
const H1Icon = (props) => <svg {...props} className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor"><path d="M4.5 17v-5h-2V9.5h2v-2h1.5v2h2V12h-2v5Zm10 0v-2.5h-2V12h2V9.5h-2V7h5v2.5h-1.5V12h1.5v2.5h-1.5V17Z"/></svg>;
const H2Icon = (props) => <svg {...props} className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24"><path d="M5.5 17q-.625 0-1.062-.438Q4 16.125 4 15.5v-2q0-.425.288-.713Q4.575 12.5 5 12.5h3V11H4.5V8.5h4q.625 0 1.062.438Q10 9.375 10 10v2q0 .425-.287.712Q9.425 13 9 13H7v1.5h3.5V17Zm10 0v-2.5h-2V12h2V9.5h-2V7h5v2.5h-1.5V12h1.5v2.5h-1.5V17Z"/></svg>;
const ChecklistIcon = (props) => <svg {...props} className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24"><path d="M12.3 14.7 9.75 12.15l-1.4 1.4L12.3 17.5l6.35-6.35-1.4-1.4ZM5 21q-.825 0-1.412-.587Q3 19.825 3 19V5q0-.825.588-1.413Q4.175 3 5 3h14q.825 0 1.413.587Q21 4.175 21 5v14q0 .825-.587 1.413Q19.825 21 19 21Z"/></svg>;
const MicrophoneIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M12 14q1.25 0 2.125-.875T15 11V5q0-1.25-.875-2.125T12 2q-1.25 0-2.125.875T9 5v6q0 1.25.875 2.125T12 14Zm-1 7v-3.075q-2.6-.35-4.3-2.325T5 11H7q0 2.075 1.463 3.537Q9.925 16 12 16t2.537-1.463Q16 13.075 16 11h2q0 2.925-1.7 4.9T13 17.925V21Z"/></svg>;
const MicOffIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M15.15 13.15 13.05 11.05V5q0-1.25-.875-2.125T10.05 2q-1.25 0-2.125.875T7.05 5v.15L5.65 3.75q.425-.325.888-.513.462-.187.962-.187h.05V2h4v1h.5q.55.05 1.013.237.462.188.887.513l-1.8 1.8ZM21.7 22.1 19.6 20q-1.075.85-2.288 1.425Q16.1 22 14.85 22v-2q.975-.3 1.875-.812.9-.513 1.625-1.188l-1.8-1.8q-.7.525-1.55.85T13.3 18.2q-2.6-.35-4.3-2.325T7.3 11H5.3q0 2.925-1.7 4.9T11.3 17.925V21h-2v-3.075q-.725-.2-1.4-.525l-2.6-2.6L2.6 1.7 4 3.1l17.7 17.7Z"/></svg>;
const SpeakerIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M14 21v-2q2.5-1.025 4-3.237 1.5-2.213 1.5-5.013t-1.5-5.012Q16.5 3.525 14 2.5V.5q3.35 1.025 5.425 3.862Q21.5 7.2 21.5 10.75t-2.075 6.888Q17.35 20.475 14 21.5ZM3 15V9h4l5-5v16l-5-5Zm7 0V9l-2.8 2.8H5v4.4h2.2Z"/></svg>;
const SpeakerOffIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M21.7 23.1 19.6 21q-1.075.85-2.287 1.425Q16.1 23 14.85 23v-2q.975-.3 1.875-.812.9-.513 1.625-1.188l-1.8-1.8q-1.425.75-2.212 2.175T13.55 22.7q0 1.925.788 3.35T16.55 28.2v2.1q-2.275-.8-3.637-2.875t-1.363-4.775q0-.325.025-.638L9.2 20H4q-.825 0-1.412-.587Q2 18.825 2 18V9q0-.825.588-1.413Q3.175 7 4 7h4L12 3v7.2L3.3 1.6 4.7 3l17 17Z"/></svg>;
const ChatIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M4 22V4q0-.825.588-1.413Q5.175 2 6 2h12q.825 0 1.413.587Q20 3.175 20 4v12q0 .825-.587 1.413Q18.825 18 18 18H8Zm2-6h10v-2H6Zm0-3h10V9H6Zm0-3h10V6H6Z"/></svg>;
const TagIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M4 22q-.825 0-1.412-.587Q2 20.825 2 20V11.5q0-.575.225-1.112.225-.538.625-.938l8.65-8.65q.95-.95 2.25-1.425T15.5 2q1.35 0 2.6.475 1.25.475 2.2 1.425l2.6 2.6q.95.95 1.425 2.2.475 1.25.475 2.6 0 1.35-.475 2.6t-1.425 2.25l-8.65 8.65q-.4.4-.937.625-.538.225-1.113.225Zm4.5-9q.625 0 1.062-.438.438-.437.438-1.062t-.438-1.062Q8.125 9 7.5 9t-1.062.438Q6 9.875 6 10.5t.438 1.062Q6.875 12 7.5 12Z"/></svg>;
const CloseIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="m12 13.4-4.9 4.9-1.4-1.4 4.9-4.9-4.9-4.9 1.4-1.4 4.9 4.9 4.9-4.9 1.4 1.4-4.9 4.9 4.9 4.9-1.4 1.4Z"/></svg>;
const MenuIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M3 18v-2h18v2Zm0-5v-2h18v2Zm0-5V6h18v2Z"/></svg>;
const PanelRightIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M2 21V3h20v18Zm2-2h16V5H4Zm12-2v-2h-2v2Zm-4 0v-2H8v2Zm4-4v-2h-2v2Zm-4 0v-2H8v2Z"/></svg>;
const SunIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M12 15q1.25 0 2.125-.875T15 12q0-1.25-.875-2.125T12 9q-1.25 0-2.125.875T9 12q0 1.25.875 2.125T12 15Zm0 2q-2.075 0-3.538-1.463Q7 14.075 7 12t1.463-3.538Q9.925 7 12 7t3.538 1.463Q17 9.925 17 12t-1.462 3.537Q14.075 17 12 17ZM2 13v-2h3v2Zm17 0v-2h3v2ZM11 5V2h2v3Zm0 17v-3h2v3ZM5.65 7.05 3.55 4.95l1.4-1.4 2.1 2.1Zm12 12-2.1-2.1 1.4-1.4 2.1 2.1Zm-1.4-12L18.35 4.95l-1.4-1.4-2.1 2.1ZM4.95 19.05l-2.1-2.1 1.4-1.4 2.1 2.1Z"/></svg>;
const MoonIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M12 21q-3.925 0-6.688-2.763Q2.55 15.475 2.55 11.55q0-3.425 2.063-5.837Q6.675 3.3 9.8 3.05q.425-.05.825.138.4.187.625.612.45 1 .3 2.125t-.6 2.025q-.45.9-1.225 1.5t-1.725.7q-.425 0-.825-.125-.4-.125-.725-.375.35.925.963 1.637.612.713 1.462 1.113 1.7.8 3.55.2 1.85-.6 3.05-2.25.25-.325.6-.488.35-.162.75-.162.75 0 1.275.525.525.525.525 1.275 0 3.925-2.762 6.687Q15.925 21 12 21Z"/></svg>;
const ImageIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M3 21q-.825 0-1.412-.587Q1 19.825 1 19V5q0-.825.588-1.413Q2.175 3 3 3h18q.825 0 1.413.587Q23 4.175 23 5v14q0 .825-.587 1.413Q21.825 21 21 21Zm-3-2h18V5H3v14Zm2-4 4-5.325 2.5 3.175L15 11l4 5Z"/></svg>;
const SearchIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="m19.6 21-6.3-6.3q-.75.6-1.725.95Q10.6 16 9.5 16q-2.725 0-4.612-1.888Q3 12.225 3 9.5t1.888-4.613Q6.775 3 9.5 3t4.613 1.887Q16 6.775 16 9.5q0 1.1-.35 2.075-.35.975-.95 1.725l6.3 6.3ZM9.5 14q1.875 0 3.188-1.312Q14 11.375 14 9.5t-1.312-3.188Q11.375 5 9.5 5 7.625 5 6.312 6.312 5 7.625 5 9.5t1.312 3.188Q7.625 14 9.5 14Z"/></svg>;
const UploadIcon = (props) => <svg {...props} className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24"><path d="M11 16V7.85l-2.6 2.6L7 9.05l5-5 5 5-1.4 1.4-2.6-2.6V16Zm-7 4q-.825 0-1.413-.588Q2 18.825 2 18V6q0-.825.588-1.413Q3.175 4 4 4h5.15q.425-.9.988-1.75.562-.85 1.362-1.25H4q-1.65 0-2.825 1.175Q0 3.35 0 5v13q0 1.65 1.175 2.825Q2.35 22 4 22h16q1.65 0 2.825-1.175Q24 19.65 24 18v-9.05q-.4.35-.825.612-.425.263-.875.438V18q0 .825-.588 1.413Q21.125 20 20.3 20Z"/></svg>;
const LinkIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M9.8 17.3q-2.225 0-3.763-1.537-1.537-1.538-1.537-3.763t1.537-3.762q1.538-1.538 3.763-1.538h4.4v2.2H9.8q-1.35 0-2.3.95-.95.95-.95 2.3t.95 2.3q.95.95 2.3.95h4.4v2.2Zm4.4-8.8v-2.2h-4.4q-2.225 0-3.763 1.538Q4.5 9.375 4.5 11.6t1.537 3.763Q7.575 16.9 9.8 16.9h4.4v-2.2H9.8q-1.35 0-2.3-.95-.95-.95-.95-2.3t.95-2.3q.95-.95 2.3-.95ZM8.5 12.7v-1.4h7v1.4Z"/></svg>;
const NoteIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M6 22q-.825 0-1.412-.587Q4 20.825 4 20V4q0-.825.588-1.413Q5.175 2 6 2h8l6 6v12q0 .825-.587 1.413Q18.825 22 18 22Zm7-13V4H6v16h12V9Z"/></svg>;
const EditIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M5 19h1.4l8.625-8.625-1.4-1.4L5 17.6ZM19.3 8.925l-4.25-4.2L17.875 1.9q.575-.575 1.413-.575.837 0 1.412.575l1.4 1.4q.575.575.6 1.388.025.812-.55 1.387ZM17.85 10.4 7.25 21H3v-4.25l10.6-10.6Zm-3.525.725-.7-.7 1.4 1.4Z"/></svg>;
const TonalityIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M12 22q-2.075 0-3.9-.788-1.825-.787-3.212-2.175-1.388-1.387-2.175-3.212Q2 13.925 2 11.85q0-2.05.788-3.875.787-1.825 2.175-3.212 1.387-1.388 3.212-2.175Q10.05 2 12.15 2H12V22h-.15q-1.925 0-3.7.788-1.775.787-3.125 2.137v-1.85q1.35-1.35 3.125-2.138Q10.225 10 12.15 10H12V4.05q-1.9.3-3.5 1.4-1.6 1.1-2.45 2.8-.85 1.7-.85 3.6 0 1.9.85 3.6t2.45 2.8q1.6 1.1 3.5 1.4Z"/></svg>; 
const BoltIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M11 21v-8H8l7-11v8h3Z"/></svg>; 
const PresentationIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M20 3H4q-.825 0-1.413.588Q2 4.175 2 5v14q0 .825.588 1.413Q3.175 21 4 21h16q.825 0 1.413-.587Q22 19.825 22 19V5q0-.825-.587-1.413Q20.825 3 20 3Zm0 16H4V5h16Zm-8-7q.625 0 1.062-.438.438-.437.438-1.062t-.438-1.062Q12.625 9 12 9t-1.062.438Q10.5 9.875 10.5 10.5t.438 1.062Q11.375 12 12 12Zm0 5.25q1.975 0 3.363-1.388 1.387-1.387 1.387-3.362t-1.387-3.363Q13.975 7.75 12 7.75t-3.363 1.387Q7.25 10.525 7.25 12.5t1.387 3.363Q10.025 17.25 12 17.25Z"/></svg>;
const SubtitlesIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M4 20q-.825 0-1.412-.587Q2 18.825 2 18V6q0-.825.588-1.413Q3.175 4 4 4h16q.825 0 1.413.587Q22 4.175 22 5v13q0 .825-.587 1.413Q20.825 20 20 20Zm0-2h16V6H4Zm2-2h8v-2H6Zm10 0h2v-2h-2Zm-6-3h8v-2h-8Zm-4 0h2v-2H6Z"/></svg>;
const GraphIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M17 19v-4.175l-2.6-2.6L17 9.6V5h-4.175l-2.6-2.6L7.6 5H3v4.6l2.6 2.6L3 14.825V19h4.6l2.6 2.6l2.6-2.6Zm-3-2v2.575L11.425 17H9.175l-2.6-2.6V12.55l2.6-2.6V9.175l2.575-2.575L14 9.175v2.25l2.6 2.6V16.6Z"/></svg>;
const TableIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M5 21q-.825 0-1.412-.587Q3 19.825 3 19V5q0-.825.588-1.413Q4.175 3 5 3h14q.825 0 1.413.587Q21 4.175 21 5v14q0 .825-.587 1.413Q19.825 21 19 21Zm0-10v8h8v-8Zm2 2h4v4H7Zm7 6h5v-8h-5ZM5 9h8V5H5Zm2 2h4V7H7Zm7 0h5V5h-5Z"/></svg>;
const TextBoxIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M4 20q-.825 0-1.412-.587Q2 18.825 2 18V6q0-.825.588-1.413Q3.175 4 4 4h16q.825 0 1.413.587Q22 4.175 22 5v13q0 .825-.587 1.413Q20.825 20 20 20Zm2-2h8v-2H6Zm10 0h2v-2h-2Zm-6-3h8v-2h-8Zm-4 0h2v-2H6Z"/></svg>;
const UserIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M12 12q-1.65 0-2.825-1.175T8 8q0-1.65 1.175-2.825T12 4q1.65 0 2.825 1.175T16 8q0 1.65-1.175 2.825T12 12Zm0 8q-3.325 0-5.662-2.338T4 12q0-3.325 2.338-5.662T12 4q3.325 0 5.662 2.338T20 12q0 3.325-2.338 5.662T12 20Zm0-2q2.5 0 4.25-1.75T18 12q0-2.5-1.75-4.25T12 6Q9.5 6 7.75 7.75T6 12q0 2.5 1.75 4.25T12 18Z"/></svg>;
const LogoutIcon = (props) => <svg {...props} fill="currentColor" viewBox="0 0 24 24"><path d="M5 21q-.825 0-1.412-.587Q3 19.825 3 19V5q0-.825.588-1.413Q4.175 3 5 3h7v2H5v14h7v2Zm11-4-1.4-1.4 2.6-2.6H9v-2h8.2l-2.6-2.6L16 7l5 5Z"/></svg>;


// --- Command Palette Component ---
const CommandPalette = ({ onClose, notes, groups, onSelectNote, onNewNote, onNewGroup, onChangeTheme, onNewFromTemplate, onQuickCapture, theme, onOpenGraph }) => {
    const [searchTerm, setSearchTerm] = useState('');
    const [filteredResults, setFilteredResults] = useState([]);
    const paletteRef = useRef(null);
    const inputRef = useRef(null); // Ref for the input element

    // Focus input on mount
    useEffect(() => {
        inputRef.current?.focus();
    }, []);

    // Define actions (ensure functions are passed correctly)
    const actions = useMemo(() => [ // Use useMemo to avoid redefining on every render
        { id: 'quickCapture', name: '⚡ Quick Capture', action: onQuickCapture, icon: <BoltIcon className="h-4 w-4 mr-2"/> },
        { id: 'newNote', name: 'Create New Note', action: onNewNote, icon: <FilePlusIcon className="h-4 w-4 mr-2"/> },
        { id: 'newGroup', name: 'Create New Group', action: onNewGroup, icon: <FolderIcon className="h-4 w-4 mr-2"/> },
        { id: 'graphView', name: '🧠 Knowledge Graph', action: onOpenGraph, icon: <GraphIcon className="h-4 w-4 mr-2"/> },
        { id: 'changeTheme', name: 'Change Theme', action: onChangeTheme, icon: theme === 'light' ? <MoonIcon className="h-4 w-4 mr-2"/> : theme === 'dark' ? <TonalityIcon className="h-4 w-4 mr-2"/> : <SunIcon className="h-4 w-4 mr-2"/> },
        ...Object.entries(TEMPLATES).map(([key, template]) => ({
             id: `template-${key}`, name: `New from: ${template.name}`, action: () => onNewFromTemplate(key), icon: <SparklesIcon className="h-4 w-4 mr-2"/>
        }))
    ], [onNewNote, onNewGroup, onChangeTheme, theme, onNewFromTemplate, onQuickCapture, onOpenGraph]); // Add dependencies

    // Filter results based on search term
    useEffect(() => {
        const lowerSearch = searchTerm.toLowerCase();
        if (!lowerSearch) {
            // Show default actions and recent notes when search is empty
            const recentNotes = notes.slice(0, 5).map(note => ({
                id: note.id,
                name: note.title || 'Untitled Note',
                type: 'note',
                action: () => onSelectNote(note),
                icon: <NoteIcon className="h-4 w-4 mr-2"/> // Using NoteIcon
            }));
            setFilteredResults([...actions, ...recentNotes]);
            return;
        }

        const filteredNotes = notes
            .filter(note => note.title.toLowerCase().includes(lowerSearch))
            .map(note => ({
                id: note.id,
                name: note.title || 'Untitled Note',
                type: 'note',
                action: () => onSelectNote(note),
                icon: <NoteIcon className="h-4 w-4 mr-2"/> // Using NoteIcon
            }));

        const filteredActions = actions.filter(action => action.name.toLowerCase().includes(lowerSearch));

        setFilteredResults([...filteredActions, ...filteredNotes]);

    }, [searchTerm, notes, groups, actions, onSelectNote]); // Include necessary dependencies, including 'actions'

    const handleAction = (actionFunc) => {
        if (typeof actionFunc === 'function') {
            actionFunc();
        }
        onClose();
    };


    return (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-start justify-center pt-20" onClick={onClose}>
            <div
                ref={paletteRef}
                className="bg-sidebar rounded-xl shadow-xl w-full max-w-xl border border-main text-text-primary overflow-hidden" // Use bg-sidebar
                onClick={e => e.stopPropagation()}
            >
                <div className="p-3 border-b border-main flex items-center gap-2">
                     <SearchIcon className="h-5 w-5 text-text-tertiary"/>
                    <input
                        ref={inputRef} // Assign ref here
                        type="text"
                        placeholder="Search notes or type command..."
                        value={searchTerm}
                        onChange={e => setSearchTerm(e.target.value)}
                        className="w-full bg-transparent outline-none text-sm placeholder:text-text-tertiary text-text-primary" // Ensure text color
                    />
                </div>
                <div className="max-h-[60vh] overflow-y-auto">
                    {filteredResults.map(result => (
                         <button
                             key={result.id}
                             onClick={() => handleAction(result.action)}
                             className="flex items-center w-full text-left px-3 py-2 text-sm hover:bg-hover text-text-primary" // Ensure text color
                         >
                            {result.icon}
                            {result.name}
                        </button>
                    ))}
                     {filteredResults.length === 0 && (
                        <div className="px-3 py-4 text-sm text-text-secondary text-center">No results found for "{searchTerm}".</div>
                    )}
                </div>
            </div>
        </div>
    );
};

// --- Main App Component ---
function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [groups, setGroups] = useState([]);
  const [notes, setNotes] = useState([]);
  const [selectedGroup, setSelectedGroup] = useState(null);
  const [selectedNote, setSelectedNote] = useState(null);
  const [modal, setModal] = useState({ isOpen: false, type: '', data: null });
  const [aiModal, setAiModal] = useState({ isOpen: false, isLoading: false, suggestion: '', error: '', action: '', structuredData: null });
  const [flashcardModal, setFlashcardModal] = useState({ isOpen: false, cards: [] });
  const [chatOpen, setChatOpen] = useState(false);
  const [linkedNotes, setLinkedNotes] = useState([]); // State for automatic connections
  
  // --- Theme State ---
  const [theme, setTheme] = useState(() => {
    const savedTheme = localStorage.getItem('notesphere-theme');
    if (savedTheme) return savedTheme;
    // Default to dark if user has preference, otherwise light
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  });

  const [layoutSettings, setLayoutSettings] = useState({ // Lifted layout state
      sidebar: false,
      notelist: false,
      connections: true,
      toolbar: false
  });
  
  const [imageModal, setImageModal] = useState({ isOpen: false, isLoading: false, imageUrl: '', error: '' });
  const [isCommandPaletteOpen, setIsCommandPaletteOpen] = useState(false);
  const [isQuickCaptureOpen, setIsQuickCaptureOpen] = useState(false); // New state for Quick Capture
  const [isPresentationOpen, setIsPresentationOpen] = useState(false); // New state for Presentation Mode
  const [isGraphOpen, setIsGraphOpen] = useState(false); // New state for Graph Modal
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false); // New state for Profile Modal
  const [renamingGroupId, setRenamingGroupId] = useState(null); // State for renaming
  const [tempGroupName, setTempGroupName] = useState(''); // Temp state for input value

  const editorRef = useRef(null);
  const titleRef = useRef(null);
  const longPressTimeoutRef = useRef(null);
  const fileInputRef = useRef(null);
  const renameInputRef = useRef(null); // Ref for rename input

  const SIDEBAR_WIDTH = 18; // Corresponds to w-72
  const NOTELIST_WIDTH = 20; // Corresponds to w-80

  // --- Theme Effect ---
  useEffect(() => {
    localStorage.setItem('notesphere-theme', theme);
    document.documentElement.classList.remove('dark-theme', 'sepia-theme');
    if (theme === 'dark') {
      document.documentElement.classList.add('dark-theme');
    } else if (theme === 'sepia') {
      document.documentElement.classList.add('sepia-theme');
    }
    // 'light' theme has no class
  }, [theme]);

  // --- Keyboard Shortcuts ---
   useEffect(() => {
    const handleKeyDown = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setIsCommandPaletteOpen(prev => !prev);
      }
       if (e.key === 'Escape') {
        setIsCommandPaletteOpen(false);
        setRenamingGroupId(null); // Cancel rename on Escape
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Effect to focus input when renaming starts
  useEffect(() => {
    if (renamingGroupId && renameInputRef.current) {
        renameInputRef.current.focus();
        renameInputRef.current.select(); // Select text for easy replacement
    }
  }, [renamingGroupId]);

  // --- Data Loading Effect ---
  useEffect(() => {
    const setDefaultContent = () => {
        const defaultGroupId = '1';
        const defaultGroup = { id: defaultGroupId, name: 'Welcome', createdAt: new Date().toISOString() };
        const defaultNote = {
            id: '101',
            groupId: defaultGroupId,
            title: 'Welcome to your new Thinking Companion!',
            content: `<h2>This is more than just a note app.</h2><p>We've added powerful AI features to help you think, create, and connect ideas faster than ever before.</p><ul><li><b>Command Palette (Cmd/Ctrl+K):</b> Instantly search notes, create new ones, or switch themes.</li><li><b>AI Quick Capture (⚡):</b> Use the new lightning bolt button to paste any text. AI will automatically title and file it for you.</li><li><b>Slash Commands:</b> In the editor, type "/" to trigger AI actions like <b>/summarize</b> or <b>/brainstorm</b> right where you type.</li><li><b>AI Analysis:</b> Use the "Highlight Key Insights" action to automatically extract summaries, tasks, and topics from your notes.</li><li><b>AI Templates:</b> Create pre-filled notes for meetings or projects from the command palette.</li><li><b>Themes:</b> Click the theme icon in the header to cycle between Light, Dark, and Sepia modes.</li></ul><p>Explore the new features and turn your notes into a dynamic second brain.</p>`,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            isPinned: false,
            tags: ['welcome', 'guide', 'ai']
        };
        return { groups: [defaultGroup], notes: [defaultNote] };
    };

    try {
        const savedUser = localStorage.getItem('notesphere-user');
        if (savedUser) setUser(JSON.parse(savedUser));

        const savedGroupsJSON = localStorage.getItem('notesphere-groups');
        const savedNotesJSON = localStorage.getItem('notesphere-notes');

        let groupsToLoad = savedGroupsJSON ? JSON.parse(savedGroupsJSON) : [];
        let notesToLoad = savedNotesJSON ? JSON.parse(savedNotesJSON) : [];

        if (groupsToLoad.length === 0 || notesToLoad.length === 0) {
            const defaults = setDefaultContent();
            groupsToLoad = defaults.groups;
            notesToLoad = defaults.notes;
        }

        setGroups(groupsToLoad);
        setNotes(notesToLoad);

        const sortedNotes = [...notesToLoad].sort((a, b) => new Date(b.updatedAt || b.createdAt) - new Date(a.updatedAt || a.createdAt));
        const mostRecentNote = sortedNotes[0];

        if (mostRecentNote) {
            const parentGroup = groupsToLoad.find(g => g.id === mostRecentNote.groupId);
            setSelectedNote(mostRecentNote);
            setSelectedGroup(parentGroup || groupsToLoad[0]);
        } else if (groupsToLoad.length > 0) {
            setSelectedGroup(groupsToLoad[0]);
            setSelectedNote(null);
        }

    } catch (error) {
        console.error("Failed to load data, resetting to default.", error);
        const defaults = setDefaultContent();
        setGroups(defaults.groups);
        setNotes(defaults.notes);
        setSelectedGroup(defaults.groups[0]);
        setSelectedNote(defaults.notes[0]);
    }
    setLoading(false);
  }, []);

  // --- Data Saving Effect ---
  useEffect(() => {
    try {
      if (!loading) {
        localStorage.setItem('notesphere-user', JSON.stringify(user));
        localStorage.setItem('notesphere-groups', JSON.stringify(groups));
        localStorage.setItem('notesphere-notes', JSON.stringify(notes));
      }
    } catch (error) { console.error("Failed to save data to localStorage", error); }
  }, [user, groups, notes, loading]);
  
  // --- Auto-find Related Notes ---
  const handleFindRelatedNotes = useCallback(async (noteToScan) => {
      if (!noteToScan) {
          setLinkedNotes([]);
          return;
      }
      
      const noteContent = noteToScan.content.replace(/<[^>]+>/g, ' ');
      if (noteContent.length < 50) { // Don't scan very short notes
            setLinkedNotes([]);
            return;
      }

      try {
          const systemPrompt = "You are a knowledge graph assistant. Read the following text and extract the 3 most important, distinct key concepts or entities. Respond with only a comma-separated list (e.g., 'concept one,second concept,third entity').";
          const payload = { contents: [{ parts: [{ text: noteContent }] }], systemInstruction: { parts: [{ text: systemPrompt }] } };
          const conceptsResponse = await callGeminiAPI(payload);
          const keyConcepts = conceptsResponse.split(',').map(c => c.trim().toLowerCase()).filter(Boolean);
          
          if (keyConcepts.length === 0) {
                setLinkedNotes([]);
                return;
          }

          const relatedNotes = notes
              .filter(n => n.id !== noteToScan.id) // Exclude the note itself
              .map(note => {
                  const content = note.content.toLowerCase().replace(/<[^>]+>/g, ' ');
                  let matchCount = 0;
                  keyConcepts.forEach(concept => {
                      if (content.includes(concept)) {
                          matchCount++;
                      }
                  });
                  return { ...note, matchCount };
              })
              .filter(note => note.matchCount > 0)
              .sort((a, b) => b.matchCount - a.matchCount)
              .slice(0, 5);
          
          setLinkedNotes(relatedNotes);
      } catch (error) {
          console.error("Could not find related notes:", error);
          setLinkedNotes([]); // Clear on error
      }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [notes]); // Only depends on 'notes'
  
  // Debounced version for useEffect
  const debouncedFindRelatedNotes = useCallback(debounce(handleFindRelatedNotes, 2000), [handleFindRelatedNotes]);
  
  useEffect(() => {
      if (selectedNote) {
          debouncedFindRelatedNotes(selectedNote);
      } else {
          setLinkedNotes([]); // Clear links if no note is selected
      }
  }, [selectedNote, debouncedFindRelatedNotes]);


  const handleLogin = (email, password) => { 
      if(email && password) setUser({ email, name: email.split('@')[0] || 'User' }); 
  };
  const handleSignUp = (email, password) => { 
      if(email && password) setUser({ email, name: email.split('@')[0] || 'User' }); 
  };
  
  const handleLogout = () => {
      setUser(null);
      setIsProfileModalOpen(false);
  };
  
  const handleUpdateName = (newName) => {
      setUser(prev => ({ ...prev, name: newName }));
  };
  
  const handleLayoutChange = (key, value) => {
      setLayoutSettings(prev => ({ ...prev, [key]: value }));
  };

  const handleSelectGroup = (group) => {
    if (renamingGroupId === group.id) return; // Don't select if renaming
    setSelectedGroup(group);
    const notesInGroup = notes.filter(n => n.groupId === group.id).sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
    setSelectedNote(notesInGroup.length > 0 ? notesInGroup[0] : null);
  };
  const handleSelectNote = (note) => { setSelectedNote(note); };

  const handleAddGroup = (name) => {
      if (!name || !name.trim()) return;
      const newGroup = { id: Date.now().toString(), name, createdAt: new Date().toISOString() };
      setGroups(prev => [...prev, newGroup]);
      closeModal();
  };

  const handleDeleteGroup = (groupId) => {
    const newGroups = groups.filter(g => g.id !== groupId);
    const newNotes = notes.filter(n => n.groupId !== groupId);
    setGroups(newGroups);
    setNotes(newNotes);

    if(selectedGroup?.id === groupId) {
        if (newGroups.length > 0) {
            handleSelectGroup(newGroups[0]);
        } else {
            setSelectedGroup(null);
            setSelectedNote(null);
        }
    }
    closeModal();
  };

    const handleAddNote = (groupId = selectedGroup?.id) => {
    if (!groupId) {
        // If no group is selected, create one or use default
        if (groups.length === 0) {
            const newGroup = { id: Date.now().toString(), name: 'My Notes', createdAt: new Date().toISOString() };
            setGroups([newGroup]);
            groupId = newGroup.id;
        } else {
            groupId = groups[0].id; // Fallback to first group
        }
    }
    const newNote = { id: Date.now().toString(), groupId: groupId, title: 'Untitled Note', content: '<p>Start writing...</p>', createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(), isPinned: false, tags: [] };
    setNotes(prev => [newNote, ...prev]);
    if (selectedGroup?.id !== groupId) {
        const targetGroup = groups.find(g => g.id === groupId);
        if(targetGroup) setSelectedGroup(targetGroup);
    }
    handleSelectNote(newNote);
    return newNote;
  };

    const handlePointerDown = (group) => {
    // Prevent starting long press if renaming
    if (renamingGroupId === group.id) return;
    longPressTimeoutRef.current = setTimeout(() => {
        handleAddNote(group.id);
        if (navigator.vibrate) {
            navigator.vibrate(50);
        }
    }, 700);
  };

  const handlePointerUp = () => {
    clearTimeout(longPressTimeoutRef.current);
  };

  const handlePointerLeave = () => {
      clearTimeout(longPressTimeoutRef.current);
  };

  // --- Rename Group Handlers ---
  const startRenamingGroup = (group) => {
      setRenamingGroupId(group.id);
      setTempGroupName(group.name);
  };

  const handleRenameGroup = (groupId, newName) => {
      if (!newName || !newName.trim()) {
          setRenamingGroupId(null); // Cancel if name is empty
          return;
      }
      setGroups(prevGroups =>
          prevGroups.map(g => (g.id === groupId ? { ...g, name: newName } : g))
      );
      setRenamingGroupId(null);
  };

  const handleRenameKeyDown = (e, groupId) => {
      if (e.key === 'Enter') {
          handleRenameGroup(groupId, tempGroupName);
      } else if (e.key === 'Escape') {
          setRenamingGroupId(null);
      }
  };
  // --- End Rename Group Handlers ---


  const handleDeleteNote = (noteId) => {
    let newNotes = notes.filter(n => n.id !== noteId);
    setNotes(newNotes);
    if (selectedNote?.id === noteId) {
        const remainingNotes = newNotes.filter(n => n.groupId === selectedGroup?.id).sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
        setSelectedNote(remainingNotes.length > 0 ? remainingNotes[0] : null);
    }
    closeModal();
  };

  const handleAddTag = (noteId, tag) => {
    if (!tag || !tag.trim()) return;
    setNotes(prev => prev.map(n => n.id === noteId ? { ...n, tags: [...new Set([...n.tags, tag.toLowerCase()])] } : n));
  };

  const handleRemoveTag = (noteId, tagToRemove) => {
    setNotes(prev => prev.map(n => n.id === noteId ? { ...n, tags: n.tags.filter(t => t !== tagToRemove) } : n));
  };

  const debouncedUpdate = useCallback(debounce((noteId, newTitle, newContent) => { setNotes(prevNotes => prevNotes.map(n => n.id === noteId ? { ...n, title: newTitle, content: newContent, updatedAt: new Date().toISOString() } : n)); }, 1000), [setNotes]);

  const handleEditorChange = useCallback(() => {
    if (selectedNote && titleRef.current && editorRef.current) {
        debouncedUpdate(selectedNote.id, titleRef.current.value, editorRef.current.innerHTML);
    }
  }, [selectedNote, debouncedUpdate]);

  const execCmd = (command, value = null) => {
    let success = false;
    try {
       // Restore focus to editor before executing command
       if (editorRef.current) editorRef.current.focus();
       success = document.execCommand(command, false, value);
    } catch (e) {
       console.error(`execCmd failed for ${command}:`, e);
    }
    if (!success) {
        console.warn(`execCmd command "${command}" might not be supported or failed.`);
    }
    handleEditorChange();
  };

  const insertChecklist = () => {
    if (editorRef.current) editorRef.current.focus();
    const listHtml = '<ul class="checklist"><li>&#8203;</li></ul>'; // Use zero-width space
    document.execCommand('insertHTML', false, listHtml);
    handleEditorChange();
  };
  
  // --- ADDED: insertTextBox function ---
  const insertTextBox = () => {
    if (editorRef.current) editorRef.current.focus();
    const boxHtml = '<div class="text-box" style="background-color: var(--hover-bg); border: 1px solid var(--border-color); border-radius: 8px; padding: 1em; margin-top: 1em; margin-bottom: 1em;"><p>&#8203;</p></div><p>&#8203;</p>'; // Add p tag after
    document.execCommand('insertHTML', false, boxHtml);
    handleEditorChange();
  };
  
  // --- ADDED: insertTable function ---
  const insertTable = (type) => {
    if (editorRef.current) editorRef.current.focus();
    let tableHtml = '';
    
    switch(type) {
        case TABLE_DESIGNS.HEADER:
            tableHtml = `<table style="width: 100%; border-collapse: collapse;"><thead><tr style="background-color: var(--hover-bg);"><th style="padding: 8px; border: 1px solid var(--border-color); text-align: left;">Header 1</th><th style="padding: 8px; border: 1px solid var(--border-color); text-align: left;">Header 2</th></tr></thead><tbody><tr><td style="padding: 8px; border: 1px solid var(--border-color);">&#8203;</td><td style="padding: 8px; border: 1px solid var(--border-color);">&nbsp;</td></tr><tr><td style="padding: 8px; border: 1px solid var(--border-color);">&nbsp;</td><td style="padding: 8px; border: 1px solid var(--border-color);">&nbsp;</td></tr></tbody></table><p>&#8203;</p>`;
            break;
        case TABLE_DESIGNS.CLEAN:
            tableHtml = `<table style="width: 100%; border-collapse: collapse;"><thead><tr><th style="padding: 8px; border-bottom: 2px solid var(--text-primary); text-align: left;">Header 1</th><th style="padding: 8px; border-bottom: 2px solid var(--text-primary); text-align: left;">Header 2</th></tr></thead><tbody><tr><td style="padding: 8px; border-bottom: 1px solid var(--border-color);">&#8203;</td><td style="padding: 8px; border-bottom: 1px solid var(--border-color);">&nbsp;</td></tr><tr><td style="padding: 8px; padding-bottom: 8px; border-bottom: 1px solid var(--border-color);">&nbsp;</td><td style="padding: 8px; border-bottom: 1px solid var(--border-color);">&nbsp;</td></tr></tbody></table><p>&#8203;</p>`;
            break;
        case TABLE_DESIGNS.SIMPLE:
        default:
             tableHtml = `<table style="width: 100%; border-collapse: collapse;" border="1"><tbody><tr><td style="padding: 8px; border: 1px solid var(--border-color);">&#8203;</td><td style="padding: 8px; border: 1px solid var(--border-color);">&nbsp;</td></tr><tr><td style="padding: 8px; border: 1px solid var(--border-color);">&nbsp;</td><td style="padding: 8px; border: 1px solid var(--border-color);">&nbsp;</td></tr></tbody></table><p>&#8203;</p>`;
    }
    
    document.execCommand('insertHTML', false, tableHtml);
    handleEditorChange();
  };

  const callGeminiAPI = async (payload, model = 'gemini-2.5-flash-preview-09-2025') => {
    const apiKey = "";
    const isTts = model === 'gemini-2.5-flash-preview-tts';
    const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

    // Exponential backoff setup
    let attempt = 0;
    const maxAttempts = 5;
    const initialDelay = 1000; // 1 second

    while (attempt < maxAttempts) {
        try {
            const response = await fetch(apiUrl, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });

            if (!response.ok) {
                 if (response.status === 429 || response.status >= 500) { // Throttling or server error
                     throw new Error(`API Error ${response.status}`); // Trigger retry
                 } else {
                     // Handle other non-retryable errors
                     const errorBody = await response.json();
                     throw new Error(`API error: ${response.statusText} - ${errorBody.error?.message || 'Unknown error'}`);
                 }
            }

            const result = await response.json();
            
            if (isTts) {
                const audioData = result?.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
                if (audioData) return audioData;
                else {
                     console.error("TTS Error Response:", JSON.stringify(result));
                     throw new Error("Could not get a valid TTS response.");
                }
            }

            // Check for candidates and content
            if (!result.candidates || result.candidates.length === 0) {
                // Check for promptFeedback
                if (result.promptFeedback && result.promptFeedback.blockReason) {
                     console.error(`Gemini Error: Request blocked due to ${result.promptFeedback.blockReason}.`);
                     throw new Error(`Request blocked by API: ${result.promptFeedback.blockReason}`);
                }
                console.error("Gemini Error: No candidates in response.", JSON.stringify(result));
                throw new Error("The AI did not provide any response.");
            }
            
            const candidate = result.candidates[0];

            // Check for safety blocks or other finish reasons
            if (candidate.finishReason && candidate.finishReason !== "STOP") {
                 console.error(`Gemini Error: Response finished due to ${candidate.finishReason}.`);
                 throw new Error(`The AI's response was interrupted: ${candidate.finishReason}`);
            }

            if (!candidate.content || !candidate.content.parts || candidate.content.parts.length === 0) {
                 console.error("Gemini Error: No content parts in response.", JSON.stringify(result));
                 throw new Error("The AI returned an empty response.");
            }

            const text = candidate.content.parts[0].text;
            if (typeof text === 'string') { // Check if text is actually a string (even empty)
                return text;
            } else {
                console.error("Gemini Error: Text field is missing or not a string in the response part.", JSON.stringify(result));
                throw new Error("Could not get a valid text response from the AI.");
            }

        } catch (error) {
             if (error.message.startsWith('API Error') && attempt < maxAttempts - 1) {
                const delay = initialDelay * Math.pow(2, attempt);
                // console.log(`Attempt ${attempt + 1} failed. Retrying in ${delay}ms...`); // Optional: log retries
                await new Promise(resolve => setTimeout(resolve, delay));
                attempt++;
            } else {
                console.error("Gemini API call failed after multiple attempts:", error);
                throw error; // Re-throw the error after max attempts or for non-retryable errors
            }
        }
    }
     throw new Error("Gemini API call failed after maximum retries."); // Should not be reached if handled correctly
};


    const callImagenAPI = async (prompt) => {
        const apiKey = "";
        const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=${apiKey}`;
        const payload = { instances: [{ prompt }], parameters: { "sampleCount": 1} };

        // Exponential backoff setup
        let attempt = 0;
        const maxAttempts = 5;
        const initialDelay = 1000; // 1 second


        while (attempt < maxAttempts) {
            try {
                const response = await fetch(apiUrl, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify(payload)
                });
                if (!response.ok) {
                    if (response.status === 429 || response.status >= 500) { // Throttling or server error
                         throw new Error(`API Error ${response.status}`); // Trigger retry
                    } else {
                        const errorBody = await response.json();
                        throw new Error(`Imagen API error: ${response.statusText} - ${errorBody.error?.message || 'Unknown error'}`);
                    }
                }
                const result = await response.json();
                if (result.predictions && result.predictions.length > 0 && result.predictions[0].bytesBase64Encoded) {
                  return `data:image/png;base64,${result.predictions[0].bytesBase64Encoded}`;
                } else {
                  throw new Error("Could not get a valid image from the Imagen API.");
                }
            } catch (error) {
                 if (error.message.startsWith('API Error') && attempt < maxAttempts - 1) {
                    const delay = initialDelay * Math.pow(2, attempt);
                    // console.log(`Attempt ${attempt + 1} failed for Imagen. Retrying in ${delay}ms...`); // Optional
                    await new Promise(resolve => setTimeout(resolve, delay));
                    attempt++;
                } else {
                    console.error("Imagen API call failed after multiple attempts:", error);
                    throw error; // Re-throw after max attempts or for non-retryable errors
                }
            }
        }
        throw new Error("Imagen API call failed after maximum retries.");
    };

  const handleAiAction = async (action, context = "") => {
    const noteContent = editorRef.current?.innerText || '';
    setAiModal({ isOpen: true, isLoading: true, suggestion: '', error: '', action, structuredData: null });

    try {
        let textToProcess;
        const selection = window.getSelection();
        if (context) {
            textToProcess = context;
        } else {
            textToProcess = selection.toString().trim() || noteContent;
        }

        if (!textToProcess && action !== AI_ACTIONS.GENERATE_FLASHCARDS && action !== AI_ACTIONS.HIGHLIGHT_INSIGHTS) {
            setAiModal({ isOpen: true, isLoading: false, error: 'Please select text or write something to process.' });
            return;
        }

        if (action === AI_ACTIONS.HIGHLIGHT_INSIGHTS) {
            const payload = {
                contents: [{ parts: [{ text: `Analyze the following note content: """${noteContent}"""` }] }],
                systemInstruction: { parts: [{ text: "You are an insightful analyst. Extract a concise 1-2 sentence summary, key action items (as a list), and the main topics (as a list) from the provided text. Ensure action items are clear tasks."}] },
                generationConfig: {
                    responseMimeType: "application/json",
                    responseSchema: {
                        type: "OBJECT",
                        properties: {
                            summary: { type: "STRING" },
                            action_items: { type: "ARRAY", items: { type: "STRING" } },
                            key_topics: { type: "ARRAY", items: { type: "STRING" } }
                        },
                        required: ["summary", "action_items", "key_topics"]
                    }
                }
            };
            const jsonText = await callGeminiAPI(payload);
            const structuredData = JSON.parse(jsonText);
            setAiModal({ isOpen: true, isLoading: false, suggestion: '', structuredData, action });

        } else if (action === AI_ACTIONS.GENERATE_FLASHCARDS) {
             if (!noteContent) {
                setAiModal({ isOpen: true, isLoading: false, error: 'Please write something in the note to generate flashcards.' });
                return;
            }
            const payload = {
              contents: [{ parts: [{ text: `Generate flashcards from this text: ${noteContent}` }] }],
              systemInstruction: { parts: [{ text: "You are a study assistant. Based on the provided text, generate a set of question-and-answer flashcards. Each flashcard should be an object with a 'q' key for the question and an 'a' key for the answer." }] },
              generationConfig: { responseMimeType: "application/json", responseSchema: { type: "ARRAY", items: { type: "OBJECT", properties: { q: { type: "STRING" }, a: { type: "STRING" } }, required: ["q", "a"] } } }
            };
            const jsonText = await callGeminiAPI(payload);
            const cards = JSON.parse(jsonText);
            setFlashcardModal({ isOpen: true, cards });
            closeAiModal();
        } else {
             let systemPrompt = '';
              switch(action) {
                case AI_ACTIONS.SUMMARIZE: systemPrompt = 'Summarize the following text concisely. Respond only with the summary.'; break;
                case AI_ACTIONS.ACTION_ITEMS: systemPrompt = 'Extract all action items from the following text as a bulleted list. If none, say so.'; break;
                case AI_ACTIONS.BRAINSTORM: systemPrompt = 'Brainstorm ideas based on the following text. Format as a list.'; break;
                case AI_ACTIONS.IMPROVE: systemPrompt = 'Improve the following text, making it clearer, more concise, and more professional. Respond only with the improved text.'; break;
                case AI_ACTIONS.FIX_GRAMMAR: systemPrompt = 'Fix all spelling and grammar errors in the following text. Respond only with the corrected text.'; break;
                case AI_ACTIONS.SHORTER: systemPrompt = 'Rewrite the following text to be significantly shorter. Respond only with the shorter text.'; break;
                case AI_ACTIONS.LONGER: systemPrompt = 'Expand on the following text, adding more detail and explanation. Respond only with the expanded text.'; break;
                case AI_ACTIONS.PROFESSIONAL: systemPrompt = 'Rewrite the following text in a professional and formal tone. Respond only with the rewritten text.'; break;
                case AI_ACTIONS.CASUAL: systemPrompt = 'Rewrite the following text in a more casual and friendly tone. Respond only with the rewritten text.'; break;
                case AI_ACTIONS.EXPLAIN_THIS: systemPrompt = 'Explain the following concept or text in a simple and easy-to-understand way. Respond only with the explanation.'; break;
                case AI_ACTIONS.GENERATE_QUIZ: systemPrompt = "You are a helpful study assistant. Based on the following text, create a short quiz with 3-5 questions to test the user's knowledge. Format the questions clearly. Provide the answers at the very end under a clear 'Answers' heading. Respond only with the quiz."; break;
                case AI_ACTIONS.CLEANUP_TRANSCRIPT: systemPrompt = "You are a helpful editor. Format the following raw speech-to-text transcript. Add punctuation, correct grammatical errors, and structure it into coherent paragraphs. If there seem to be different speakers, label them as 'Speaker 1', 'Speaker 2', etc., and start each speaker on a new line. Respond only with the cleaned-up text."; break;
                default: systemPrompt = `Perform this action: "${action}". Respond only with the improved text.`;
            }
             const payload = {
                contents: [{ parts: [{ text: textToProcess }] }],
                systemInstruction: { parts: [{ text: systemPrompt }] }
            };
            const suggestion = await callGeminiAPI(payload);
            setAiModal({ isOpen: true, isLoading: false, suggestion, error: '', action });
        }
    } catch (error) {
        setAiModal({ isOpen: true, isLoading: false, suggestion: '', error: `Failed to get suggestion. ${error.message}`, action, structuredData: null });
    }
  };

  const handleSuggestTags = async () => {
    const noteContent = editorRef.current?.innerText;
    if (!noteContent || !selectedNote) return [];
    try {
        const systemPrompt = "Analyze the following note content and suggest 3 to 5 relevant, single-word, lowercase tags. Respond with only a comma-separated list of tags (e.g., 'react,javascript,webdev').";
        const payload = {
            contents: [{ parts: [{ text: `Note Content: """${noteContent}"""` }] }],
            systemInstruction: { parts: [{ text: systemPrompt }] }
        };
        const response = await callGeminiAPI(payload);
        return response.split(',').map(tag => tag.trim()).filter(Boolean);
    } catch (error) {
        console.error("Tag suggestion error:", error);
        return [];
    }
  };

  const handleGenerateImage = async () => {
    const noteContent = editorRef.current?.innerText || '';
    if (!noteContent.trim()) {
        setImageModal({ isOpen: true, isLoading: false, imageUrl: '', error: 'Please write something in the note to generate an image.' });
        return;
    }
    setImageModal({ isOpen: true, isLoading: true, imageUrl: '', error: '' });
    try {
        const promptSystemInstruction = { parts: [{ text: "You are a prompt generator. Based on the following text, create a short, descriptive, and visually rich prompt for an image generation model. The prompt should capture the essence of the text in a single sentence. Respond only with the prompt." }] };
        const promptPayload = {
            contents: [{ parts: [{ text: noteContent.substring(0, 1000) }] }],
            systemInstruction: promptSystemInstruction
        };
        const imagePrompt = await callGeminiAPI(promptPayload);

        const imageUrl = await callImagenAPI(imagePrompt);
        setImageModal({ isOpen: true, isLoading: false, imageUrl, error: '' });
    } catch (error) {
        setImageModal({ isOpen: true, isLoading: false, imageUrl: '', error: `Failed to generate image. ${error.message}` });
    }
  };


   const handleFileUpload = (e) => {
        const file = e.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (event) => {
            const dataUrl = event.target.result;
            
            if (file.type.startsWith('image/')) {
                 const mediaHtml = `<p style="text-align: center;"><img src="${dataUrl}" alt="${file.name}" style="width: 75%; border-radius: 12px; display: inline-block;" /></p><p>&nbsp;</p>`;
                 if (editorRef.current) editorRef.current.focus();
                 execCmd('insertHTML', mediaHtml);
            } else if (file.type.startsWith('audio/')) {
                // Open modal to ask for transcription
                openModal('transcribeAudio', { dataUrl, file });
            } else if (file.type.startsWith('video/')) {
                 const mediaHtml = `<p style="text-align: center;"><video controls src="${dataUrl}" style="width: 75%; border-radius: 12px; display: inline-block;">Your browser does not support the video tag.</video></p><p>&nbsp;</p>`;
                 if (editorRef.current) editorRef.current.focus();
                 execCmd('insertHTML', mediaHtml);
            } else {
                console.warn("Unsupported file type:", file.type);
                return;
            }
        };

        if (file.type.startsWith('image/') || file.type.startsWith('audio/') || file.type.startsWith('video/')) {
            reader.readAsDataURL(file);
        }
        e.target.value = null; // Reset file input
    };
    
    // This is the new transcribe handler called by the modal
    const handleTranscribeAudio = async (file, dataUrl) => {
        closeModal();
        setAiModal({ isOpen: true, isLoading: true, action: `Transcribing ${file.name}...` });
        
        try {
            const base64Audio = dataUrl.split(',')[1];
            // Corrected payload object
            const payload = {
              "contents": [
                { "role": "user",
                  "parts": [
                    { "inlineData": { "mimeType": file.type, "data": base64Audio } },
                    { "text": "Transcribe this audio. If there are multiple distinct speakers, label them as 'Speaker 1', 'Speaker 2', etc., and start each speaker on a new line." }
                  ]
                }
              ]
            };
            
            const transcript = await callGeminiAPI(payload, "gemini-2.5-flash-preview-09-2025"); // Use the standard model endpoint for audio
            
            const transcriptHtml = `
                <blockquote>
                    <p><strong>Transcription:</strong></p>
                    <p>${transcript.replace(/\n/g, '<br />')}</p>
                </blockquote>
                <p><audio controls src="${dataUrl}">Your browser does not support the audio element.</audio></p>
                <p>&nbsp;</p>
            `;
            
            if (editorRef.current) editorRef.current.focus();
            execCmd('insertHTML', transcriptHtml);
            closeAiModal();
            
        } catch (error) {
             setAiModal({isOpen: true, isLoading: false, error: `Failed to transcribe audio: ${error.message}`});
             // As a fallback, just insert the audio player
             const mediaHtml = `<p><audio controls src="${dataUrl}">Your browser does not support the audio element.</audio></p><p>&nbsp;</p>`;
             if (editorRef.current) editorRef.current.focus();
             execCmd('insertHTML', mediaHtml);
        }
    };

    
    // --- Theme Cycling ---
    const cycleTheme = () => {
        setTheme(currentTheme => {
            if (currentTheme === 'light') return 'dark';
            if (currentTheme === 'dark') return 'sepia';
            return 'light'; // Cycles from sepia back to light
        });
    };
    
    const getThemeIcon = () => {
        if (theme === 'light') return <MoonIcon className="h-6 w-6" />;
        if (theme === 'dark') return <TonalityIcon className="h-6 w-6" />;
        return <SunIcon className="h-6 w-6" />; // Sepia theme shows Sun icon to go back to light
    };


  const openModal = (type, data = null) => setModal({ isOpen: true, type, data });
  const closeModal = () => setModal({ isOpen: false, type: '', data: null });
  const closeAiModal = () => setAiModal({ isOpen: false, isLoading: false, suggestion: '', error: '', action: '', structuredData: null });
  
  // --- AI Quick Capture Handler ---
  const handleQuickCapture = async (content) => {
    setIsQuickCaptureOpen(false);
    setAiModal({ isOpen: true, isLoading: true, action: '✨ AI Quick Capture' });
    try {
        const groupNames = groups.map(g => g.name).join(', ');
        const systemPrompt = `You are a note-filing assistant. Analyze the following text. Your task is to: 1. Generate a concise, descriptive title (max 10 words). 2. Determine which of the following groups is the *best* fit for this note: [${groupNames}]. 3. Format the text for a note (e.g., add line breaks, fix punctuation). Respond *only* with a JSON object with keys: "title", "suggestedGroupName", and "formattedContent".`;
        
        const payload = {
            contents: [{ parts: [{ text: content }] }],
            systemInstruction: { parts: [{ text: systemPrompt }] },
            generationConfig: {
                responseMimeType: "application/json",
                responseSchema: {
                    type: "OBJECT",
                    properties: {
                        title: { type: "STRING" },
                        suggestedGroupName: { type: "STRING" },
                        formattedContent: { type: "STRING" }
                    },
                    required: ["title", "suggestedGroupName", "formattedContent"]
                }
            }
        };

        const jsonText = await callGeminiAPI(payload);
        const { title, suggestedGroupName, formattedContent } = JSON.parse(jsonText);

        const targetGroup = groups.find(g => g.name.toLowerCase() === suggestedGroupName.toLowerCase());
        let groupId = targetGroup ? targetGroup.id : null;
        
        if (!groupId) {
            // If no group matches or groups are empty, create a new note in the first group or a new 'Inbox' group
            if (groups.length === 0) {
                 const newGroup = { id: Date.now().toString(), name: 'Inbox', createdAt: new Date().toISOString() };
                 setGroups([newGroup]);
                 groupId = newGroup.id;
            } else {
                groupId = groups[0].id; // Default to first group
            }
        }

        const newNote = { 
            id: Date.now().toString(), 
            groupId: groupId, 
            title: title || 'Quick Capture', 
            content: formattedContent || content, 
            createdAt: new Date().toISOString(), 
            updatedAt: new Date().toISOString(), 
            isPinned: false, 
            tags: ['capture'] 
        };
        
        setNotes(prev => [newNote, ...prev]);
        handleSelectNote(newNote); // Select the new note
        
        const finalGroup = groups.find(g => g.id === groupId) || groups[0];
        if (selectedGroup?.id !== groupId && finalGroup) {
             handleSelectGroup(finalGroup);
        }
        
        closeAiModal();

    } catch (error) {
         setAiModal({isOpen: true, isLoading: false, error: `Failed to capture note: ${error.message}`});
    }
  };

  // --- Render ---
  if (loading) return <div className="flex items-center justify-center h-screen bg-background text-text-primary"><Spinner /></div>;
  if (!user) return <AuthScreen onLogin={handleLogin} onSignUp={handleSignUp} />;

  return (
    <>
      <div className={`h-screen w-screen bg-background text-text-primary flex overflow-hidden font-sans relative`}>
        <style>{`
          :root { 
            --background: #f7f9f9; 
            --sidebar-bg: #f7f9f9; 
            --note-list-bg: #ffffff; 
            --text-primary: #1f1f1f; 
            --text-secondary: #444746; 
            --text-tertiary: #70757a;
            --border-color: #c4c7c5; 
            --hover-bg: #f1f3f4; 
            --input-bg: #ffffff;
            --primary-bg: #0b57d0; 
            --primary-hover: #0a4cb5; 
            --primary-text: #ffffff;
            --danger-bg: #d93025; 
            --danger-hover: #c5221f;
            --active-bg: #c2e7ff;
            --active-text: #001d35;
          }
          .dark-theme, :root.dark-theme {
            --background: #1f1f1f; 
            --sidebar-bg: #1f1f1f; 
            --note-list-bg: #1f1f1f; 
            --text-primary: #e3e3e3; 
            --text-secondary: #c4c7c5; 
            --text-tertiary: #8e918f;
            --border-color: #444746; 
            --hover-bg: #2d2d2d; 
            --input-bg: #1f1f1f;
            --primary-bg: #a8c7fa; 
            --primary-hover: #b8d2fb; 
            --primary-text: #001d35;
            --danger-bg: #f28b82; 
            --danger-hover: #f39a94;
            --active-bg: #2d313c;
            --active-text: #a8c7fa;
          }
          .sepia-theme, :root.sepia-theme {
            --background: #f4f1de; 
            --sidebar-bg: #f4f1de; 
            --note-list-bg: #fcfaf0; 
            --text-primary: #585040; 
            --text-secondary: #70685a; 
            --text-tertiary: #928a7c;
            --border-color: #dcd8c8; 
            --hover-bg: #ece8d9; 
            --input-bg: #fcfaf0;
            --primary-bg: #d76e00;
            --primary-hover: #b65d00; 
            --primary-text: #ffffff;
            --danger-bg: #d93025; 
            --danger-hover: #c5221f;
            --active-bg: #e6dfc8;
            --active-text: #585040;
          }
          
          body { 
            font-family: 'Google Sans Text', 'Roboto', -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; 
            -webkit-font-smoothing: antialiased; 
            -moz-osx-font-smoothing: grayscale;
            background-color: var(--background);
            color: var(--text-primary);
            transition: background-color 0.3s ease, color 0.3s ease;
          }
          .bg-background { background-color: var(--background); } .text-text-primary { color: var(--text-primary); } 
          .text-text-secondary { color: var(--text-secondary); } .text-text-tertiary { color: var(--text-tertiary); }
          .bg-sidebar { background-color: var(--sidebar-bg); } .bg-note-list { background-color: var(--note-list-bg); } 
          .border-main { border-color: var(--border-color); } .bg-input { background-color: var(--input-bg); } 
          .hover\\:bg-hover:hover { background-color: var(--hover-bg); } 
          .bg-primary-bg { background-color: var(--primary-bg); } .hover\\:bg-primary-hover:hover { background-color: var(--primary-hover); }
          .text-primary-text { color: var(--primary-text); }
          .bg-danger { background-color: var(--danger-bg); } .hover\\:bg-danger-hover:hover { background-color: var(--danger-hover); }
          .bg-active { background-color: var(--active-bg); } .text-active-text { color: var(--active-text); }
          .group:hover .group-hover\\:opacity-100 { opacity: 1; }
          .prose { color: var(--text-primary); max-width: 100%; } .prose strong { color: var(--text-primary); } 
          .prose h1, .prose h2, .prose h3, .prose h4 { color: var(--text-primary); border: none; } .prose blockquote { border-left-color: var(--primary-bg); color: var(--text-secondary); }
          .prose code { background-color: var(--hover-bg); padding: 0.2em 0.4em; margin: 0; font-size: 85%; border-radius: 6px; }
          .prose pre { background-color: var(--hover-bg); padding: 1em; border-radius: 0.5rem; }
          .prose a { color: var(--primary-bg); }
          .prose ul:not(.checklist) { list-style-type: disc; padding-left: 1.75rem; }
          .prose ul:not(.checklist) li { margin-top: 0.25em; margin-bottom: 0.25em; }
          .prose ul.checklist > li { list-style-type: none; padding-left: 0; }
          .prose ul.checklist > li::before { content: '☐'; margin-right: 0.75em; cursor: pointer; color: var(--text-secondary); font-family: monospace; } 
          .prose ul.checklist > li.checked::before { content: '☑'; color: var(--primary-bg); } 
          .prose audio, .prose video { max-width: 100%; border-radius: 8px; }
          /* --- Image Resize --- */
          .prose img {
            resize: horizontal; /* Allow horizontal resizing */
            overflow: auto; /* Required for resize handle */
            border: 2px dashed transparent;
            max-width: 100%; /* Can't be resized larger than its container */
            height: auto;
          }
          .prose img:hover,
          .prose img:focus {
            /* Show a border when interacting */
            border-color: var(--primary-bg);
            outline: none;
          }
          /* --- Text Box --- */
          .prose .text-box {
            background-color: var(--hover-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 1em;
            margin-top: 1em;
            margin-bottom: 1em;
          }
          
          .flashcard { width: 100%; height: 100%; position: relative; transform-style: preserve-3d; transition: transform 0.6s; }
          .flashcard.is-flipped { transform: rotateY(180deg); }
          .flashcard-face { position: absolute; width: 100%; height: 100%; backface-visibility: hidden; display: flex; align-items: center; justify-content: center; padding: 20px; text-align: center; font-size: 1.25rem; border-radius: 1rem; }
          .flashcard-front { background-color: var(--input-bg); border: 1px solid var(--border-color); }
          .flashcard-back { background-color: var(--hover-bg); transform: rotateY(180deg); }
        `}</style>

        <aside className={`bg-sidebar flex-shrink-0 flex flex-col transition-all duration-300 ${layoutSettings.sidebar ? 'w-0 overflow-hidden' : 'w-72'}`}>
          <div className="p-4 flex items-center h-16 flex-shrink-0">
              <svg className="h-8 w-8 mr-2 text-primary-bg" viewBox="0 0 24 24" fill="currentColor"><path d="M14.5,1.55L20.45,7.5V19.55C20.45,21.15 19.2,22.4 17.6,22.4H6.4C4.8,22.4 3.55,21.15 3.55,19.55V4.45C3.55,2.85 4.8,1.55 6.4,1.55H14.5M13.5,3.55H6.4C5.9,3.55 5.55,3.9 5.55,4.45V19.55C5.55,20.1 5.9,20.45 6.4,20.45H17.6C18.1,20.45 18.45,20.1 18.45,19.55V8.55H13.5V3.55Z" /></svg>
              <h1 className="text-xl font-medium tracking-tight text-text-primary">NoteSphere</h1>
          </div>
          <div className="p-4 flex items-center gap-2">
              <button onClick={() => openModal('addGroup')} className="w-full text-sm font-medium p-3 rounded-2xl bg-primary-bg text-primary-text shadow-sm hover:shadow-md transition-shadow flex items-center justify-center"><PlusIcon className="h-5 w-5 mr-2"/> New Group</button>
              <button onClick={() => setIsQuickCaptureOpen(true)} title="AI Quick Capture" className="flex-shrink-0 text-sm font-medium p-3 rounded-2xl bg-hover text-text-primary shadow-sm hover:shadow-md transition-shadow">
                <BoltIcon className="h-5 w-5"/>
              </button>
              <button onClick={() => setIsGraphOpen(true)} title="Knowledge Graph" className="flex-shrink-0 text-sm font-medium p-3 rounded-2xl bg-hover text-text-primary shadow-sm hover:shadow-md transition-shadow">
                <GraphIcon className="h-5 w-5"/>
              </button>
          </div>
          <nav className="flex-1 overflow-y-auto px-4 space-y-1">
            {groups.map((group) => (
              <div
                key={group.id}
                className={`group flex items-center justify-between p-3 rounded-lg cursor-pointer transition-colors ${selectedGroup?.id === group.id ? 'bg-active text-active-text font-medium' : 'hover:bg-hover text-text-secondary'}`}
                onMouseDown={() => handlePointerDown(group)}
                onMouseUp={handlePointerUp}
                onMouseLeave={handlePointerLeave}
                onTouchStart={() => handlePointerDown(group)}
                onTouchEnd={handlePointerUp}
                onTouchCancel={handlePointerLeave}
                onDoubleClick={() => startRenamingGroup(group)} // Double click to rename
              >
                <div onClick={() => handleSelectGroup(group)} className="flex items-center truncate flex-1 mr-2">
                    <FolderIcon className="h-5 w-5 mr-4 flex-shrink-0" />
                    {renamingGroupId === group.id ? (
                        <input
                            ref={renameInputRef}
                            type="text"
                            value={tempGroupName}
                            onChange={(e) => setTempGroupName(e.target.value)}
                            onBlur={() => handleRenameGroup(group.id, tempGroupName)}
                            onKeyDown={(e) => handleRenameKeyDown(e, group.id)}
                            className="text-sm bg-input border border-primary-bg rounded px-1 py-0.5 outline-none flex-1 w-full text-text-primary" // Ensure text color
                            onClick={(e) => e.stopPropagation()} // Prevent click from selecting group
                        />
                    ) : (
                        <span className="text-sm truncate">{group.name}</span>
                    )}
                </div>
                 {renamingGroupId !== group.id && ( // Hide delete when renaming
                    <button onClick={(e) => { e.stopPropagation(); openModal('deleteGroup', group)}} className="opacity-0 group-hover:opacity-100 p-1 rounded-full hover:bg-black/10 dark:hover:bg-white/10">
                        <TrashIcon className="h-4 w-4 text-text-tertiary" />
                    </button>
                 )}
              </div>
            ))}
          </nav>
          
          {/* --- Profile Section --- */}
          <div className="p-2 border-t border-main">
            <button 
              onClick={() => setIsProfileModalOpen(true)} 
              className="w-full flex items-center gap-3 p-3 rounded-lg hover:bg-hover text-text-primary"
            >
              <div className="w-8 h-8 rounded-full bg-primary-bg text-primary-text flex items-center justify-center font-medium">
                {user?.name ? user.name[0].toUpperCase() : 'U'}
              </div>
              <span className="text-sm font-medium truncate">{user?.name || 'User Profile'}</span>
            </button>
          </div>
          
        </aside>

        <button
          onClick={() => handleLayoutChange('sidebar', !layoutSettings.sidebar)}
          className="absolute top-1/2 -translate-y-8 z-20 bg-sidebar/80 backdrop-blur-sm border border-main rounded-full p-1 text-text-secondary hover:bg-hover hover:text-text-primary"
          style={{
            left: layoutSettings.sidebar ? '0.5rem' : `calc(${SIDEBAR_WIDTH}rem - 1.25rem)`,
            transition: 'left 0.3s ease-in-out'
           }}
          title={layoutSettings.sidebar ? "Show Sidebar" : "Hide Sidebar"}
        >
          {layoutSettings.sidebar ? <ChevronRightIcon className="h-5 w-5" /> : <ChevronLeftIcon className="h-5 w-5" />}
        </button>

        <section className={`bg-note-list border-l border-r border-main flex-col flex-shrink-0 flex transition-all duration-300 ${layoutSettings.notelist ? 'w-0 overflow-hidden' : 'w-80'}`}>
              <div className="p-4 border-b border-main h-16 flex items-center justify-between">
                  <h2 className="text-xl font-medium truncate text-text-primary">{selectedGroup ? selectedGroup.name : "All Notes"}</h2>
                  <button onClick={() => handleAddNote()} disabled={!selectedGroup && groups.length === 0} className="p-2 rounded-full hover:bg-hover disabled:opacity-50 disabled:cursor-not-allowed text-text-secondary"><FilePlusIcon className="h-5 w-5"/></button>
              </div>
              <div className="flex-1 overflow-y-auto p-2">
                {notes.filter(n => !selectedGroup || n.groupId === selectedGroup.id).sort((a,b) => new Date(b.updatedAt) - new Date(a.updatedAt)).map(note => (
                    <div key={note.id} onClick={() => handleSelectNote(note)} className={`p-3 rounded-lg cursor-pointer mb-1 border ${selectedNote?.id === note.id ? 'border-primary-bg/70 bg-active' : 'border-transparent hover:bg-hover'}`}>
                        <h4 className="font-medium text-sm truncate mb-1 text-text-primary">{note.title || 'Untitled Note'}</h4>
                        <p className="text-xs text-text-secondary truncate">{formatDate(note.updatedAt)} <span className="ml-2">{(note.content || '').replace(/<[^>]+>/g, '').substring(0, 20)}...</span></p>
                    </div>
                ))}
              </div>
        </section>

        <button
            onClick={() => handleLayoutChange('notelist', !layoutSettings.notelist)}
            className="absolute top-1/2 translate-y-0 z-20 bg-sidebar/80 backdrop-blur-sm border border-main rounded-full p-1 text-text-secondary hover:bg-hover hover:text-text-primary"
            style={{
              left: `calc(${(layoutSettings.sidebar ? 0 : SIDEBAR_WIDTH)}rem + ${layoutSettings.notelist ? '0.5rem' : `calc(${NOTELIST_WIDTH}rem - 1.25rem)`})`,
              transition: 'left 0.3s ease-in-out'
            }}
            title={layoutSettings.notelist ? "Show Notes" : "Hide Notes"}
          >
            {layoutSettings.notelist ? <ChevronRightIcon className="h-5 w-5" /> : <ChevronLeftIcon className="h-5 w-5" />}
          </button>

        <main className="flex-1 flex flex-col bg-background">
            <header className="flex-shrink-0 h-16 flex items-center justify-end px-4">
              <div className="flex items-center gap-2">
                 <button onClick={() => setIsCommandPaletteOpen(true)} className="p-2 rounded-full hover:bg-hover text-text-secondary flex items-center gap-1 text-sm">
                    <SearchIcon className="h-5 w-5"/> <span className="hidden sm:inline">Search...</span>
                    <kbd className="ml-2 hidden sm:inline text-xs border border-main px-1.5 py-0.5 rounded">⌘K</kbd>
                </button>
                <button onClick={cycleTheme} title={`Change theme (Current: ${theme})`} className="p-2 rounded-full hover:bg-hover text-text-secondary">
                    {getThemeIcon()}
                </button>
              </div>
            </header>
            {selectedNote ? (
                <NoteEditor
                    key={selectedNote.id} note={selectedNote}
                    editorRef={editorRef} titleRef={titleRef} onContentChange={handleEditorChange}
                    onDelete={() => openModal('deleteNote', selectedNote)}
                    onAiAction={handleAiAction} execCmd={execCmd} onOpenChat={() => setChatOpen(true)}
                    onAddTag={handleAddTag} onRemoveTag={handleRemoveTag} handleSuggestTags={handleSuggestTags}
                    callGeminiAPI={callGeminiAPI} onGenerateImage={handleGenerateImage}
                    insertChecklist={insertChecklist}
                    insertTextBox={insertTextBox}
                    insertTable={insertTable}
                    fileInputRef={fileInputRef} handleFileUpload={handleFileUpload}
                    linkedNotes={linkedNotes}
                    onSelectNote={handleSelectNote}
                    isConnectionsCollapsed={layoutSettings.connections}
                    setIsConnectionsCollapsed={(val) => handleLayoutChange('connections', val)}
                    isToolbarCollapsed={layoutSettings.toolbar}
                    setIsToolbarCollapsed={(val) => handleLayoutChange('toolbar', val)}
                    onOpenPresentation={() => setIsPresentationOpen(true)}
                />
            ) : (
                    <div className="flex-1 flex items-center justify-center text-center text-text-secondary p-4">
                      <div className="flex flex-col items-center">
                        <svg className="w-24 h-24 text-text-tertiary/50 mb-4" viewBox="0 0 24 24" fill="currentColor"><path d="M14.5,1.55L20.45,7.5V19.55C20.45,21.15 19.2,22.4 17.6,22.4H6.4C4.8,22.4 3.55,21.15 3.55,19.55V4.45C3.55,2.85 4.8,1.55 6.4,1.55H14.5M13.5,3.55H6.4C5.9,3.55 5.55,3.9 5.55,4.45V19.55C5.55,20.1 5.9,20.45 6.4,20.45H17.6C18.1,20.45 18.45,20.1 18.45,19.55V8.55H13.5V3.55Z" /></svg>
                        <h2 className="text-2xl font-medium text-text-primary">Select a note</h2>
                        <p className="mt-1">Or create a new one to get started.</p>
                      </div>
                  </div>
            )}
        </main>
      </div>

      {isCommandPaletteOpen && <CommandPalette
        onClose={() => setIsCommandPaletteOpen(false)}
        notes={notes}
        groups={groups}
        onSelectNote={(note) => { handleSelectNote(note); setIsCommandPaletteOpen(false); }}
        onNewNote={() => { handleAddNote(); setIsCommandPaletteOpen(false); }}
        onNewGroup={() => { openModal('addGroup'); setIsCommandPaletteOpen(false); }}
        onChangeTheme={() => { cycleTheme(); setIsCommandPaletteOpen(false); }}
        onQuickCapture={() => { setIsQuickCaptureOpen(true); setIsCommandPaletteOpen(false); }}
        onOpenGraph={() => { setIsGraphOpen(true); setIsCommandPaletteOpen(false); }}
        onNewFromTemplate={(templateKey) => {
            const topic = prompt(`What is the topic for your "${TEMPLATES[templateKey].name}"?`);
            if(topic) {
                openModal('aiTemplate', { templateKey, topic });
            }
            setIsCommandPaletteOpen(false);
        }}
        theme={theme}
      />}
      
      {isQuickCaptureOpen && <QuickCaptureModal 
        onClose={() => setIsQuickCaptureOpen(false)} 
        onCapture={handleQuickCapture} 
      />}
      
      {isPresentationOpen && selectedNote && <PresentationModal
        note={selectedNote}
        onClose={() => setIsPresentationOpen(false)}
      />}
      
      {isGraphOpen && <KnowledgeGraphModal
        notes={notes}
        groups={groups}
        onClose={() => setIsGraphOpen(false)}
        onSelectNote={(note) => {
            handleSelectNote(note);
            setIsGraphOpen(false);
        }}
        callGeminiAPI={callGeminiAPI}
      />}
      
      {isProfileModalOpen && <ProfileModal
        onClose={() => setIsProfileModalOpen(false)}
        user={user}
        onUpdateName={handleUpdateName}
        onLogout={handleLogout}
        theme={theme}
        onChangeTheme={cycleTheme}
        layoutSettings={layoutSettings}
        onLayoutChange={handleLayoutChange}
      />}

      {modal.isOpen && (
        <Modal
            {...modal}
            onClose={closeModal}
            onDeleteNote={handleDeleteNote}
            onAddGroup={handleAddGroup}
            onDeleteGroup={handleDeleteGroup}
            onAiTemplateGenerate={async ({templateKey, topic}) => {
                closeModal(); // Close prompt modal first
                setAiModal({ isOpen: true, isLoading: true, action: `Generating ${TEMPLATES[templateKey].name}...` }); // Show loading
                try {
                    const prompt = TEMPLATES[templateKey].prompt(topic);
                    const content = await callGeminiAPI({ contents: [{parts: [{text: prompt}]}] });
                    const newNote = handleAddNote(); // Creates and selects the new note
                    // Update the newly created note's title and content
                    const newTitle = `${TEMPLATES[templateKey].name}: ${topic}`;
                    const updatedNote = { ...newNote, title: newTitle, content: content };
                    setNotes(prev => prev.map(n => n.id === newNote.id ? updatedNote : n));
                     // Make sure the state update reflects immediately for the editor
                    setSelectedNote(updatedNote); // Update selectedNote to match
                    closeAiModal(); // Close loading modal
                } catch (error) {
                    setAiModal({isOpen: true, isLoading: false, error: `Failed to generate template: ${error.message}`});
                }
            }}
            onTranscribe={handleTranscribeAudio} // Pass transcribe handler
        />
      )}
      {aiModal.isOpen && <AIModal {...aiModal} onClose={closeAiModal} onAccept={(suggestion) => {
          if (editorRef.current) {
              if (editorRef.current) editorRef.current.focus(); // Ensure focus
              document.execCommand('insertHTML', false, suggestion.replace(/\n/g, '<br>'));
              handleEditorChange();
          }
          closeAiModal();
      }} onSelectNote={(note) => {handleSelectNote(note); closeAiModal();}} />}
      <FlashcardModal isOpen={flashcardModal.isOpen} onClose={() => setFlashcardModal({isOpen: false, cards: []})} cards={flashcardModal.cards} />
      {chatOpen && selectedNote && <ChatModal isOpen={chatOpen} onClose={() => setChatOpen(false)} note={selectedNote} callGeminiAPI={callGeminiAPI} />}
      <ImageModal
        {...imageModal}
        onClose={() => setImageModal({ isOpen: false, isLoading: false, imageUrl: '', error: '' })}
        onAccept={(imageUrl) => {
            if (editorRef.current) {
                if (editorRef.current) editorRef.current.focus(); // Ensure focus
                const imgHtml = `<p style="text-align: center;"><img src="${imageUrl}" alt="Generated from note" style="width: 75%; border-radius: 12px; display: inline-block;" /></p><p>&nbsp;</p>`;
                document.execCommand('insertHTML', false, imgHtml);
                handleEditorChange();
            }
            setImageModal({ isOpen: false, isLoading: false, imageUrl: '', error: '' });
        }}
    />
    </>
  );
}

// --- AuthScreen Component ---
const AuthScreen = ({ onLogin, onSignUp }) => {
    const [isLogin, setIsLogin] = useState(true);
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');

    const handleSubmit = (e) => {
        e.preventDefault();
        if (isLogin) {
            onLogin(email, password);
        } else {
            onSignUp(email, password);
        }
    };
    return (
        <div className={`flex items-center justify-center h-screen bg-background text-text-primary`}>
            <div className="w-full max-w-sm p-8 space-y-6 bg-sidebar rounded-2xl shadow-sm border border-main">
                <h1 className="text-2xl font-medium text-center">NoteSphere</h1>
                <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                        <input placeholder="Email" type="email" value={email} onChange={e => setEmail(e.target.value)} required className="w-full px-4 py-3 mt-1 rounded-lg bg-input border border-main focus:outline-none focus:ring-2 focus:ring-primary-bg placeholder:text-text-tertiary" />
                    </div>
                    <div>
                        <input placeholder="Password" type="password" value={password} onChange={e => setPassword(e.target.value)} required className="w-full px-4 py-3 mt-1 rounded-lg bg-input border border-main focus:outline-none focus:ring-2 focus:ring-primary-bg placeholder:text-text-tertiary" />
                    </div>
                    <button type="submit" className="w-full py-3 font-semibold text-primary-text bg-primary-bg rounded-full hover:bg-primary-hover transition-colors">
                        {isLogin ? 'Login' : 'Sign Up'}
                    </button>
                </form>
                <p className="text-sm text-center text-text-secondary">
                    {isLogin ? "Don't have an account?" : "Already have an account?"}
                    <button onClick={() => setIsLogin(!isLogin)} className="ml-1 font-semibold text-primary-bg hover:underline">{isLogin ? 'Sign Up' : 'Login'}</button>
                </p>
            </div>
        </div>
    );
};

// --- NoteEditor Component ---
const NoteEditor = ({ note, editorRef, titleRef, onContentChange, onDelete, onAiAction, execCmd, onOpenChat, onAddTag, onRemoveTag, handleSuggestTags, callGeminiAPI, onGenerateImage, insertChecklist, insertTextBox, insertTable, fileInputRef, handleFileUpload, linkedNotes, onSelectNote, isConnectionsCollapsed, setIsConnectionsCollapsed, isToolbarCollapsed, setIsToolbarCollapsed, onOpenPresentation }) => {
    const [tagInput, setTagInput] = useState('');
    const [suggestedTags, setSuggestedTags] = useState([]);
    const [isRecording, setIsRecording] = useState(false);
    const [isPlaying, setIsPlaying] = useState(false);
    const [slashMenu, setSlashMenu] = useState({ open: false, x: 0, y: 0, filter: '' });
    
    const recognitionRef = useRef(null);
    const audioRef = useRef(null);
    const mediaRecorderRef = useRef(null); // Ref for MediaRecorder
    const audioChunksRef = useRef([]); // Ref to store audio chunks

    const EDITOR_TOOLBAR_WIDTH = 4; // Corresponds to w-16 -> 4rem
    const CONNECTIONS_PANEL_WIDTH = 14; // Corresponds to w-56

    // Close slash menu on note change
    useEffect(() => {
        setSlashMenu({ open: false, x: 0, y: 0, filter: '' });
    }, [note.id]);

    const handleEditorInput = useCallback((e) => {
        onContentChange();
        
        const selection = window.getSelection();
        if (selection.rangeCount > 0) {
            const range = selection.getRangeAt(0);
            const node = range.commonAncestorContainer;
            
            // Check if we are in a text node
            if (node.nodeType === Node.TEXT_NODE) {
                const text = node.textContent.substring(0, range.startOffset);
                const slashMatch = text.match(/\/([a-zA-Z]*)$/);
                
                if (slashMatch) {
                    const rect = range.getBoundingClientRect();
                    setSlashMenu({ open: true, x: rect.left, y: rect.bottom + 5, filter: slashMatch[1] });
                } else {
                    setSlashMenu({ open: false, x: 0, y: 0, filter: '' });
                }
            } else if (e.inputType === 'deleteContentBackward') { // Handle backspace
                 setSlashMenu({ open: false, x: 0, y: 0, filter: '' });
            }
        }
    }, [onContentChange]);

    useEffect(() => {
        if (titleRef.current) titleRef.current.value = note.title;
        if (editorRef.current) editorRef.current.innerHTML = note.content;

        const editorNode = editorRef.current; // Capture ref value

        const handler = (e) => {
            if(e.target.tagName === 'LI' && e.target.parentElement.classList.contains('checklist')) {
                e.target.classList.toggle('checked');
                onContentChange(); // Trigger save on check/uncheck
            }
        };
        
        editorNode?.addEventListener('click', handler);
        editorNode?.addEventListener('input', handleEditorInput);
        
        return () => {
            editorNode?.removeEventListener('click', handler);
            editorNode?.removeEventListener('input', handleEditorInput);
        };
    }, [note, onContentChange, handleEditorInput]);

    const handleTagKeyDown = (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            onAddTag(note.id, tagInput);
            setTagInput('');
        }
    };

    const fetchAndSetTags = async () => {
        const tags = await handleSuggestTags();
        setSuggestedTags(tags);
    };

    const handleVoiceInput = async () => {
        if (isRecording) {
            recognitionRef.current?.stop(); // This will trigger its 'onend'
            setIsRecording(false);
            return;
        }

        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        if (!SpeechRecognition || !navigator.mediaDevices?.getUserMedia) {
            alert("Speech recognition or audio recording not supported in this browser.");
            return;
        }

        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            
            // 1. Setup MediaRecorder to save the audio file
            mediaRecorderRef.current = new MediaRecorder(stream);
            audioChunksRef.current = []; // Clear previous chunks
            
            mediaRecorderRef.current.ondataavailable = (event) => {
                audioChunksRef.current.push(event.data);
            };
            
            mediaRecorderRef.current.onstop = () => {
                // Create audio blob and insert it
                const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/webm' });
                const audioUrl = URL.createObjectURL(audioBlob);
                const mediaHtml = `<p><audio controls src="${audioUrl}">Your browser does not support the audio element.</audio></p><p>&nbsp;</p>`;
                if (editorRef.current) {
                    editorRef.current.focus();
                    document.execCommand('insertHTML', false, mediaHtml);
                }
                
                // Stop all media tracks to turn off mic light
                stream.getTracks().forEach(track => track.stop());
            };

            // 2. Setup SpeechRecognition for real-time text
            const recognition = new SpeechRecognition();
            recognition.continuous = true;
            recognition.interimResults = true;
            recognition.lang = 'en-US';

            recognition.onstart = () => {
                setIsRecording(true);
            };

            recognition.onend = () => {
                if (mediaRecorderRef.current?.state === "recording") {
                    mediaRecorderRef.current.stop();
                }
                setIsRecording(false);
            };

            recognition.onerror = (event) => {
                console.error('Speech recognition error:', event.error);
                if (mediaRecorderRef.current?.state === "recording") {
                    mediaRecorderRef.current.stop();
                }
                setIsRecording(false);
            };

            recognition.onresult = (event) => {
                let interim_transcript = '';
                let final_transcript = '';
                for (let i = event.resultIndex; i < event.results.length; ++i) {
                    if (event.results[i].isFinal) {
                        final_transcript += event.results[i][0].transcript;
                    } else {
                        interim_transcript += event.results[i][0].transcript;
                    }
                }
                if (final_transcript) {
                    if (editorRef.current) editorRef.current.focus();
                    document.execCommand('insertText', false, final_transcript + ' ');
                    onContentChange(); // Trigger save
                }
            };
            
            // 3. Start both
            mediaRecorderRef.current.start();
            recognition.start();
            recognitionRef.current = recognition;

        } catch (err) {
            console.error("Failed to get audio permissions:", err);
            alert("Could not start recording. Please grant microphone permissions.");
        }
    };

    const handleReadAloud = async () => {
        if (isPlaying) {
            if (audioRef.current) {
                audioRef.current.pause();
                audioRef.current.currentTime = 0;
            }
            setIsPlaying(false);
            return;
        }

        const textToRead = editorRef.current?.innerText;
        if(!textToRead) return;
        setIsPlaying(true);
        try {
            const payload = {
                contents: [{ parts: [{ text: `Say it clearly: ${textToRead.substring(0, 5000)}` }] }], // Limit text length
                generationConfig: { responseModalities: ["AUDIO"], speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: "Kore" } } } },
                model: "gemini-2.5-flash-preview-tts"
            };
            const base64Audio = await callGeminiAPI(payload, 'gemini-2.5-flash-preview-tts');
            const pcmData = base64ToArrayBuffer(base64Audio);
            const wavBlob = pcmToWav(pcmData, 24000); // Standard sample rate for TTS
            const audioUrl = URL.createObjectURL(wavBlob);
            const audio = new Audio(audioUrl);
            audioRef.current = audio;
            audio.play();
            audio.onended = () => setIsPlaying(false);
            audio.onerror = (e) => {
                console.error("Audio playback error:", e);
                setIsPlaying(false);
            };
        } catch (error) {
            console.error("Text-to-speech error:", error);
            setIsPlaying(false);
        }
    };
    
    const handleSlashCommand = (actionKey, actionFunc) => {
        if (editorRef.current) editorRef.current.focus();
        
        // Find the range of the slash command
        const selection = window.getSelection();
        const range = selection.getRangeAt(0);
        const node = range.commonAncestorContainer;

        if (node.nodeType === Node.TEXT_NODE) {
            const text = node.textContent.substring(0, range.startOffset);
            const slashMatch = text.match(/\/([a-zA-Z]*)$/);
            if (slashMatch) {
                // Select the slash command text and delete it
                range.setStart(node, slashMatch.index);
                range.setEnd(node, range.startOffset);
                document.execCommand('delete', false);
            }
        }
        
        setSlashMenu({ open: false, x: 0, y: 0, filter: '' });
        
        // Execute the command
        actionFunc();
    };
    
    const allSlashCommands = useMemo(() => {
        const ai = Object.entries(AI_ACTIONS).map(([key, name]) => ({
            key, name, action: () => onAiAction(name)
        }));
        const editor = [
            { key: 'TODO', name: EDITOR_COMMANDS.TODO, action: insertChecklist },
            { key: 'H1', name: EDITOR_COMMANDS.H1, action: () => execCmd('formatBlock', '<h1>') },
            { key: 'H2', name: EDITOR_COMMANDS.H2, action: () => execCmd('formatBlock', '<h2>') },
            { key: 'TEXT_BOX', name: EDITOR_COMMANDS.TEXT_BOX, action: insertTextBox },
            { key: 'TABLE', name: EDITOR_COMMANDS.TABLE, action: () => insertTable(TABLE_DESIGNS.SIMPLE) },
        ];
        return [...editor, ...ai];
    }, [onAiAction, execCmd, insertChecklist, insertTextBox, insertTable]); // Fixed dependencies
    
    const filteredSlashCommands = useMemo(() => {
        return allSlashCommands
            .filter(cmd => cmd.name.toLowerCase().includes(slashMenu.filter.toLowerCase()))
    }, [slashMenu.filter, allSlashCommands]);

    return (
        <div className="flex-1 flex flex-col md:flex-row overflow-hidden relative">
            {slashMenu.open && (
                <div 
                    className="fixed z-20 bg-sidebar border border-main rounded-lg shadow-xl p-1 max-h-60 overflow-y-auto"
                    style={{ top: slashMenu.y, left: slashMenu.x }}
                    onMouseDown={e => e.preventDefault()} // Prevent focus loss
                >
                    {filteredSlashCommands.length > 0 ? (
                        filteredSlashCommands.map((cmd) => (
                            <button 
                                key={cmd.key}
                                onMouseDown={e => e.preventDefault()} // Prevent focus loss on click
                                onClick={() => handleSlashCommand(cmd.key, cmd.action)}
                                className="block w-full text-left px-3 py-1.5 text-sm rounded-lg hover:bg-hover text-text-primary"
                            >
                                {cmd.name}
                            </button>
                        ))
                    ) : (
                        <div className="px-3 py-1.5 text-sm text-text-secondary">No matching command...</div>
                    )}
                </div>
            )}
            
            {/* Connections Panel */}
            <button
                onClick={() => setIsConnectionsCollapsed(!isConnectionsCollapsed)}
                className="absolute top-1/2 -translate-y-1/2 bg-sidebar/80 backdrop-blur-sm border border-main rounded-full p-1 z-10 hidden md:block"
                style={{ left: `${isConnectionsCollapsed ? 1 : CONNECTIONS_PANEL_WIDTH + 1}rem`, transition: 'left 0.3s ease-in-out' }}
                title={isConnectionsCollapsed ? "Show Connections" : "Hide Connections"}
            >
                {isConnectionsCollapsed ? <ChevronRightIcon className="h-5 w-5" /> : <ChevronLeftIcon className="h-5 w-5" />}
            </button>
            <div className={`flex-shrink-0 border-r border-main flex flex-col transition-all duration-300 ${isConnectionsCollapsed ? 'w-0 overflow-hidden' : 'w-56'}`}>
                <h3 className="p-4 text-sm font-medium text-text-secondary sticky top-0 bg-sidebar/80 backdrop-blur-sm">🧠 Connections</h3>
                <div className="flex-1 overflow-y-auto p-2 space-y-1">
                    {linkedNotes.length > 0 ? (
                        linkedNotes.map(note => (
                             <button key={note.id} onClick={() => onSelectNote(note)} className="block w-full text-left p-2 rounded-lg hover:bg-hover">
                                 <p className="text-sm font-medium text-text-primary truncate">{note.title || 'Untitled Note'}</p>
                                 <p className="text-xs text-text-tertiary truncate">{note.content.replace(/<[^>]+>/g, '').substring(0, 50)}...</p>
                             </button>
                        ))
                    ) : (
                        <p className="p-2 text-xs text-text-tertiary text-center">No related notes found.</p>
                    )}
                </div>
            </div>
            
            <div className="flex-1 flex flex-col overflow-y-auto">
                <div className="p-4 flex items-center justify-between gap-2">
                    <input ref={titleRef} type="text" defaultValue={note.title} onInput={onContentChange} className="w-full text-2xl bg-transparent outline-none text-text-primary placeholder:text-text-tertiary" placeholder="Note Title" />
                    <div className="flex items-center flex-shrink-0">
                        <button onClick={onOpenPresentation} title="Presentation Mode" className="p-2 rounded-full hover:bg-hover text-text-secondary hover:text-text-primary">
                            <PresentationIcon className="h-5 w-5"/>
                        </button>
                        
                        <div className="group relative flex justify-center">
                            <ToolbarButton title="AI Actions"><SparklesIcon className="h-5 w-5 text-primary-bg"/></ToolbarButton>
                            <div className="absolute right-0 top-full mt-2 w-56 bg-sidebar rounded-2xl shadow-lg p-1 z-10 hidden group-hover:block transition-opacity duration-300 border border-main">
                               {Object.values(AI_ACTIONS).map(action => (
                                 <button 
                                   key={action} 
                                   onMouseDown={e => e.preventDefault()} // <-- FIX: Prevent focus loss
                                   onClick={() => onAiAction(action)} 
                                   className="block w-full text-left px-3 py-1.5 text-sm rounded-lg hover:bg-hover text-text-primary"
                                 >
                                   {action}
                                 </button>
                               ))}
                            </div>
                        </div>
                    </div>
                </div>
                <div
                    ref={editorRef}
                    contentEditable
                    suppressContentEditableWarning
                    onInput={handleEditorInput} // Use combined handler
                    className="flex-1 px-6 pb-4 overflow-y-auto prose focus:outline-none"
                ></div>
                <div className="px-6 py-2 border-t border-main">
                    <div className="flex items-center gap-2 flex-wrap">
                        {note.tags?.map(tag => (
                            <div key={tag} className="flex items-center bg-input text-xs text-text-secondary px-2 py-1 rounded-full border border-main">
                                <span>{tag}</span>
                                <button onClick={() => onRemoveTag(note.id, tag)} className="ml-1.5 text-text-tertiary hover:text-text-primary">
                                    <CloseIcon className="h-3 w-3" />
                                </button>
                            </div>
                        ))}
                        <input
                            type="text"
                            value={tagInput}
                            onChange={(e) => setTagInput(e.target.value)}
                            onKeyDown={handleTagKeyDown}
                            placeholder="Add a tag..."
                            className="bg-transparent outline-none text-xs flex-1 placeholder:text-text-tertiary"
                        />
                    </div>
                     {suggestedTags.length > 0 && (
                        <div className="mt-2 flex items-center gap-2 flex-wrap">
                            <span className="text-xs text-text-secondary">Suggestions:</span>
                            {suggestedTags.map(tag => (
                                <button key={tag} onClick={() => { onAddTag(note.id, tag); setSuggestedTags(prev => prev.filter(t => t !== tag)) }} className="bg-hover text-xs text-text-primary px-2 py-1 rounded-full hover:bg-active-bg hover:text-active-text">
                                    + {tag}
                                </button>
                            ))}
                        </div>
                    )}
                </div>
            </div>
             <button
                onClick={() => setIsToolbarCollapsed(!isToolbarCollapsed)}
                className="absolute top-1/2 -translate-y-1/2 bg-sidebar/80 backdrop-blur-sm border border-main rounded-full p-1 z-10 hidden md:block"
                style={{ right: `${isToolbarCollapsed ? 1 : EDITOR_TOOLBAR_WIDTH + 1}rem`, transition: 'right 0.3s ease-in-out' }}
                title={isToolbarCollapsed ? "Show Toolbar" : "Hide Toolbar"}
            >
                {isToolbarCollapsed ? <ChevronLeftIcon className="h-5 w-5" /> : <ChevronRightIcon className="h-5 w-5" />}
            </button>
             <div className={`order-first md:order-last flex-shrink-0 border-t md:border-t-0 md:border-l border-main p-2 flex md:flex-col items-center justify-center md:justify-start gap-2 overflow-x-auto md:overflow-y-auto transition-all duration-300 ${isToolbarCollapsed ? 'md:w-0 md:p-0 md:overflow-hidden' : 'md:w-16'}`}>
                    {/* File input for media uploads */}
                    <input type="file" ref={fileInputRef} onChange={handleFileUpload} accept="image/*, audio/*, video/*" className="hidden" />
                    <ToolbarButton title="Upload Media" onClick={() => fileInputRef.current.click()}><UploadIcon/></ToolbarButton>
                    <ToolbarSeparator/>
                    <ToolbarButton title="Bold" onClick={() => execCmd('bold')}><BoldIcon/></ToolbarButton>
                    <ToolbarButton title="Italic" onClick={() => execCmd('italic')}><ItalicIcon/></ToolbarButton>
                    <ToolbarButton title="Underline" onClick={() => execCmd('underline')}><UnderlineIcon/></ToolbarButton>
                    <ToolbarButton title="Strikethrough" onClick={() => execCmd('strikeThrough')}><StrikethroughIcon/></ToolbarButton>
                    <ToolbarSeparator/>
                    <ToolbarButton title="Heading 1" onClick={() => execCmd('formatBlock', '<h1>')}><H1Icon /></ToolbarButton>
                    <ToolbarButton title="Heading 2" onClick={() => execCmd('formatBlock', '<h2>')}><H2Icon /></ToolbarButton>
                    <ToolbarButton title="Blockquote" onClick={() => execCmd('formatBlock', '<blockquote>')}><QuoteIcon/></ToolbarButton>
                    <ToolbarButton title="Code Block" onClick={() => execCmd('formatBlock', '<pre>')}><CodeIcon/></ToolbarButton>
                    <ToolbarSeparator/>
                    <ToolbarButton title="Unordered List" onClick={() => execCmd('insertUnorderedList')}><ListIcon/></ToolbarButton>
                    <ToolbarButton title="Checklist" onClick={insertChecklist}><ChecklistIcon/></ToolbarButton>
                    <ToolbarButton title="Text Box" onClick={insertTextBox}><TextBoxIcon className="h-5 w-5"/></ToolbarButton>
                    {/* Table Dropdown */}
                    <div className="group relative flex justify-center">
                        <ToolbarButton title="Insert Table"><TableIcon className="h-5 w-5"/></ToolbarButton>
                        <div className="absolute right-full top-0 mr-2 w-48 bg-sidebar rounded-2xl shadow-lg p-1 z-10 hidden group-hover:block transition-opacity duration-300 border border-main">
                           {Object.values(TABLE_DESIGNS).map(design => (
                             <button 
                               key={design} 
                               onMouseDown={e => e.preventDefault()} 
                               onClick={() => insertTable(design)} 
                               className="block w-full text-left px-3 py-1.5 text-sm rounded-lg hover:bg-hover text-text-primary"
                             >
                               {design}
                             </button>
                           ))}
                        </div>
                    </div>
                    <ToolbarSeparator/>
                    <ToolbarButton title="Voice Memo" onClick={handleVoiceInput}>
                       {isRecording ? <MicOffIcon className="h-5 w-5 text-red-500" /> : <MicrophoneIcon className="h-5 w-5"/>}
                    </ToolbarButton>
                     <ToolbarButton title="Read Aloud" onClick={handleReadAloud}>
                       {isPlaying ? <SpeakerOffIcon className="h-5 w-5 text-red-500" /> : <SpeakerIcon className="h-5 w-5"/>}
                    </ToolbarButton>
                    <ToolbarButton title="✨ Generate Image" onClick={onGenerateImage}><ImageIcon className="h-5 w-5"/></ToolbarButton>
                    <ToolbarButton title="Chat with Note" onClick={onOpenChat}><ChatIcon className="h-5 w-5"/></ToolbarButton>
                    <ToolbarButton title="Suggest Tags" onClick={fetchAndSetTags}><TagIcon className="h-5 w-5" /></ToolbarButton>
                    <ToolbarSeparator/>
                    <ToolbarButton title="Delete Note" onClick={onDelete}><TrashIcon className="h-5 w-5 text-text-tertiary hover:text-danger-bg"/></ToolbarButton>
            </div>
        </div>
    );
};

// --- Modal Component ---
const Modal = ({ type, data, onClose, onDeleteNote, onAddGroup, onDeleteGroup, onAiTemplateGenerate, onTranscribe }) => {
    const [groupName, setGroupName] = useState('');
    const [isLoading, setIsLoading] = useState(false); // For template generation

    const handleGenerateTemplate = async () => {
        if (!data?.templateKey || !data?.topic) return;
        setIsLoading(true);
        await onAiTemplateGenerate(data); // Call the async function passed from App
        // Loading state is handled in App component after this call resolves
    };

    const renderContent = () => {
        switch(type) {
            case 'deleteNote':
                return (
                    <>
                        <h3 className="text-lg font-medium">Delete Note</h3>
                        <p className="mt-2 text-sm text-text-secondary">Are you sure you want to delete "{data?.title}"? This action cannot be undone.</p>
                        <div className="mt-6 flex justify-end gap-3">
                            <button onClick={onClose} className="px-4 py-2 text-sm font-medium rounded-full hover:bg-hover text-text-primary">Cancel</button>
                            <button onClick={() => onDeleteNote(data.id)} className="px-4 py-2 text-sm font-medium text-white bg-danger rounded-full hover:bg-danger-hover">Delete</button>
                        </div>
                    </>
                );
             case 'deleteGroup':
                 return (
                    <>
                        <h3 className="text-lg font-medium">Delete Group</h3>
                        <p className="mt-2 text-sm text-text-secondary">Are you sure you want to delete "{data?.name}" and all its notes? This action cannot be undone.</p>
                        <div className="mt-6 flex justify-end gap-3">
                            <button onClick={onClose} className="px-4 py-2 text-sm font-medium rounded-full hover:bg-hover text-text-primary">Cancel</button>
                            <button onClick={() => onDeleteGroup(data.id)} className="px-4 py-2 text-sm font-medium text-white bg-danger rounded-full hover:bg-danger-hover">Delete</button>
                        </div>
                    </>
                );
             case 'addGroup':
                 return (
                     <>
                        <h3 className="text-lg font-medium">New Group</h3>
                        <input
                            type="text"
                            value={groupName}
                            onChange={e => setGroupName(e.target.value)}
                            placeholder="Enter group name"
                            className="w-full px-3 py-2 mt-4 rounded-lg bg-input border border-main focus:outline-none focus:ring-2 focus:ring-primary-bg text-text-primary placeholder:text-text-tertiary"
                            autoFocus
                        />
                        <div className="mt-6 flex justify-end gap-3">
                            <button onClick={onClose} className="px-4 py-2 text-sm font-medium rounded-full hover:bg-hover text-text-primary">Cancel</button>
                            <button onClick={() => onAddGroup(groupName)} className="px-4 py-2 text-sm font-medium text-primary-text bg-primary-bg rounded-full hover:bg-primary-hover">Add Group</button>
                        </div>
                    </>
                );
             case 'aiTemplate':
                return (
                    <>
                        <h3 className="text-lg font-medium">Generate from Template</h3>
                        <p className="mt-2 text-sm text-text-secondary">Generate "{TEMPLATES[data?.templateKey]?.name}" note about "{data?.topic}"?</p>
                        <div className="mt-6 flex justify-end gap-3">
                            <button onClick={onClose} className="px-4 py-2 text-sm font-medium rounded-full hover:bg-hover text-text-primary">Cancel</button>
                            <button onClick={handleGenerateTemplate} disabled={isLoading} className="px-4 py-2 text-sm font-medium text-primary-text bg-primary-bg rounded-full hover:bg-primary-hover disabled:opacity-50 min-w-[5rem] flex justify-center">
                                {isLoading ? <Spinner/> : 'Generate'}
                            </button>
                        </div>
                    </>
                );
             case 'transcribeAudio':
                return (
                    <>
                        <h3 className="text-lg font-medium">Transcribe Audio</h3>
                        <p className="mt-2 text-sm text-text-secondary">Would you like to transcribe "{data?.file?.name}"? This will use the AI to generate text from the audio.</p>
                        <div className="mt-6 flex justify-end gap-3">
                            <button onClick={() => {
                                const mediaHtml = `<p><audio controls src="${data?.dataUrl}">Your browser does not support the audio element.</audio></p><p>&nbsp;</p>`;
                                execCmd('insertHTML', mediaHtml);
                                onClose();
                            }} className="px-4 py-2 text-sm font-medium rounded-full hover:bg-hover text-text-primary">Embed Only</button>
                            <button onClick={() => onTranscribe(data.file, data.dataUrl)} className="px-4 py-2 text-sm font-medium text-primary-text bg-primary-bg rounded-full hover:bg-primary-hover">
                                ✨ Transcribe
                            </button>
                        </div>
                    </>
                );
            default: return null;
        }
    };

    return (
        <div className={`fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4`} onClick={onClose}>
            <div className="bg-sidebar rounded-2xl shadow-xl w-full max-w-md p-6 border border-main text-text-primary" onClick={e => e.stopPropagation()}>
                {renderContent()}
            </div>
        </div>
    );
};


// --- AI Modal Component ---
const AIModal = ({ isLoading, suggestion, error, onClose, action, structuredData, onAccept, onSelectNote }) => {

    const renderStructuredData = () => {
        if (!structuredData) return null;

        if (action === AI_ACTIONS.HIGHLIGHT_INSIGHTS) {
            return (
                <div className="space-y-4 prose">
                    <h4>Summary</h4>
                    <p>{structuredData.summary || 'No summary available.'}</p>
                    <h4>Action Items</h4>
                    {structuredData.action_items && structuredData.action_items.length > 0 ? (
                        <ul>{structuredData.action_items.map((item, i) => <li key={i}>{item}</li>)}</ul>
                    ) : <p>No action items found.</p>}
                     <h4>Key Topics</h4>
                    {structuredData.key_topics && structuredData.key_topics.length > 0 ? (
                        <p className="text-sm">{structuredData.key_topics.join(', ')}</p>
                    ) : <p>No key topics identified.</p>}
                </div>
            );
        }
         if (action === 'Related Notes') {
             return (
                 <div className="space-y-2">
                     <h4 className="font-medium text-sm text-text-secondary">Related Notes:</h4>
                     {structuredData.related && structuredData.related.length > 0 ? (
                         structuredData.related.map(note => (
                             <button key={note.id} onClick={() => onSelectNote(note)} className="block w-full text-left p-2 rounded-lg hover:bg-hover">
                                 <p className="text-sm font-medium text-text-primary">{note.title || 'Untitled Note'}</p>
                                 <p className="text-xs text-text-tertiary truncate">{note.content.replace(/<[^>]+>/g, '').substring(0, 100)}...</p>
                             </button>
                         ))
                     ) : <p className="text-sm text-text-secondary">No related notes found.</p>}
                 </div>
             );
         }
        // Add rendering logic for other structured data types if needed
        return null;
    };

    return (
        <div className={`fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4`} onClick={onClose}>
            <div className="bg-sidebar rounded-2xl shadow-xl w-full max-w-2xl p-6 border border-main text-text-primary flex flex-col max-h-[80vh]" onClick={e => e.stopPropagation()}>
                <h3 className="text-lg font-medium flex items-center gap-2 flex-shrink-0"><SparklesIcon className="h-5 w-5 text-primary-bg"/> {action || 'AI Assistant'}</h3>
                <div className="mt-4 p-4 rounded-lg bg-input border border-main overflow-y-auto flex-1">
                    {isLoading && <div className="flex items-center justify-center h-full"><Spinner/></div>}
                    {error && <p className="text-red-400">{error}</p>}
                    {/* Render suggestion OR structured data */}
                    {suggestion && <div className="prose" dangerouslySetInnerHTML={{ __html: suggestion.replace(/\n/g, '<br>') }} />}
                    {structuredData && renderStructuredData()}
                </div>
                <div className="mt-6 flex justify-end gap-3 flex-shrink-0">
                    <button onClick={onClose} className="px-4 py-2 text-sm font-medium rounded-full hover:bg-hover text-text-primary">Close</button>
                    {/* Show Accept only for text suggestions */}
                    {suggestion && !error && <button onClick={() => onAccept(suggestion)} className="px-4 py-2 text-sm font-medium text-primary-text bg-primary-bg rounded-full hover:bg-primary-hover">Accept</button>}
                </div>
            </div>
        </div>
    );
};


// --- ImageModal Component ---
const ImageModal = ({ isOpen, isLoading, imageUrl, error, onClose, onAccept }) => {
     if (!isOpen) return null;
    return (
        <div className={`fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4`} onClick={onClose}>
             <div className="bg-sidebar rounded-2xl shadow-xl w-full max-w-2xl p-6 border border-main flex flex-col text-text-primary" onClick={e => e.stopPropagation()}>
                <h3 className="text-lg font-medium flex items-center gap-2">✨ Generate Image</h3>
                <div className="mt-4 min-h-[300px] rounded-lg bg-input border border-main flex items-center justify-center overflow-hidden">
                    {isLoading && <Spinner/>}
                    {error && <p className="text-red-400 p-4 text-center">{error}</p>}
                    {imageUrl && <img src={imageUrl} alt="Generated from note" className="max-w-full max-h-[50vh] object-contain" />}
                </div>
                <div className="mt-6 flex justify-end gap-3">
                    <button onClick={onClose} className="px-4 py-2 text-sm font-medium rounded-full hover:bg-hover text-text-primary">Close</button>
                    {imageUrl && !error && <button onClick={() => onAccept(imageUrl)} className="px-4 py-2 text-sm font-medium text-primary-text bg-primary-bg rounded-full hover:bg-primary-hover">Insert Image</button>}
                </div>
            </div>
        </div>
    );
};

// --- FlashcardModal Component ---
const FlashcardModal = ({ isOpen, onClose, cards }) => {
    const [currentIndex, setCurrentIndex] = useState(0);
    const [isFlipped, setIsFlipped] = useState(false);

    useEffect(() => {
        setCurrentIndex(0);
        setIsFlipped(false);
    }, [cards]);

    if (!isOpen) return null;

    const currentCard = cards.length > 0 ? cards[currentIndex] : null; // Handle empty cards array

    const goToNext = () => { if (cards.length > 0) { setIsFlipped(false); setTimeout(() => setCurrentIndex(prev => (prev + 1) % cards.length), 300); }};
    const goToPrev = () => { if (cards.length > 0) { setIsFlipped(false); setTimeout(() => setCurrentIndex(prev => (prev - 1 + cards.length) % cards.length), 300); }};


    return (
        <div className={`fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4`} onClick={onClose}>
             <div className="bg-sidebar rounded-2xl shadow-xl w-full max-w-2xl p-6 relative border border-main text-text-primary" onClick={e => e.stopPropagation()}>
                <h3 className="text-lg font-medium mb-4">Flashcards</h3>
                <div className="aspect-video w-full perspective-1000">
                    {currentCard ? (
                        <div className={`flashcard ${isFlipped ? 'is-flipped' : ''}`} onClick={() => setIsFlipped(!isFlipped)}>
                            <div className="flashcard-face flashcard-front">{currentCard.q}</div>
                            <div className="flashcard-face flashcard-back">{currentCard.a}</div>
                        </div>
                    ) : <div className="flex items-center justify-center h-full text-text-secondary">No cards generated.</div>}
                </div>
                 <div className="mt-4 flex justify-between items-center">
                    <button onClick={goToPrev} disabled={cards.length === 0} className="px-4 py-2 rounded-full bg-hover text-text-primary disabled:opacity-50">Prev</button>
                    <span className="text-sm text-text-secondary">{cards.length > 0 ? currentIndex + 1 : 0} / {cards.length}</span>
                    <button onClick={goToNext} disabled={cards.length === 0} className="px-4 py-2 rounded-full bg-hover text-text-primary disabled:opacity-50">Next</button>
                </div>
                <button onClick={onClose} className="absolute top-4 right-4 text-text-secondary hover:text-text-primary p-1 rounded-full text-2xl leading-none">&times;</button>
            </div>
        </div>
    );
};

// --- ChatModal Component ---
const ChatModal = ({ isOpen, onClose, note, callGeminiAPI }) => {
    const [messages, setMessages] = useState([]);
    const [input, setInput] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const messagesEndRef = useRef(null);

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    };

    useEffect(scrollToBottom, [messages]);

    const handleSend = async (messageText) => {
        const textToSend = messageText || input;
        if (!textToSend.trim()) return;

        const newMessages = [...messages, { role: 'user', text: textToSend }];
        setMessages(newMessages);
        setInput('');
        setIsLoading(true);

        const conversationHistory = newMessages.map(m => ({
            role: m.role === 'bot' ? 'model' : 'user',
            parts: [{text: m.text}]
        }));

        try {
            const systemPrompt = `You are a helpful assistant. The user is asking questions about the following note. Use the note content to answer. Provide a concise answer and then suggest 3 relevant follow-up questions the user could ask. Note Title: "${note.title}". Note Content: """${note.content.replace(/<[^>]+>/g, '')}"""`;

            const payload = {
                contents: conversationHistory,
                systemInstruction: { parts: [{ text: systemPrompt }] },
                generationConfig: {
                    responseMimeType: "application/json",
                    responseSchema: {
                        type: "OBJECT",
                        properties: {
                            answer: { type: "STRING" },
                            suggestions: {
                                type: "ARRAY",
                                items: { type: "STRING" }
                            }
                        },
                        required: ["answer", "suggestions"]
                    }
                }
            };
            const jsonText = await callGeminiAPI(payload);
            const structuredResponse = JSON.parse(jsonText);

            setMessages([...newMessages, { role: 'bot', text: structuredResponse.answer, suggestions: structuredResponse.suggestions }]);
        } catch (error) {
            setMessages([...newMessages, { role: 'bot', text: `Sorry, I had trouble responding. ${error.message}` }]);
        } finally {
            setIsLoading(false);
        }
    };

    if (!isOpen) return null;

    return (
        <div className={`fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4`} onClick={onClose}>
             <div className="bg-sidebar rounded-2xl shadow-xl w-full max-w-lg h-[80vh] flex flex-col border border-main text-text-primary" onClick={e => e.stopPropagation()}>
                <div className="p-4 border-b border-main flex-shrink-0">
                    <h3 className="font-medium">Chat with "{note.title}"</h3>
                </div>
                <div className="flex-1 p-4 overflow-y-auto space-y-4">
                    {messages.map((msg, index) => (
                        <div key={index} className="flex flex-col">
                            <div className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                                <div className={`max-w-[80%] p-3 rounded-2xl ${msg.role === 'user' ? 'bg-primary-bg text-primary-text' : 'bg-hover text-text-primary'}`}>
                                    {msg.text}
                                </div>
                            </div>
                             {msg.role === 'bot' && msg.suggestions && (
                                <div className="mt-2 flex flex-wrap gap-2 justify-start">
                                    {msg.suggestions.map((s, i) => (
                                        <button key={i} onClick={() => handleSend(s)} className="text-xs text-primary-bg bg-primary-bg/10 px-2 py-1 rounded-full border border-primary-bg/30 hover:bg-primary-bg/20">
                                            {s}
                                        </button>
                                    ))}
                                </div>
                            )}
                        </div>
                    ))}
                    {isLoading && <div className="flex justify-start"><div className="p-3 rounded-lg bg-input"><Spinner/></div></div>}
                    <div ref={messagesEndRef} />
                </div>
                <div className="p-4 border-t border-main flex-shrink-0">
                    <div className="flex gap-2">
                        <input value={input} onChange={e => setInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && handleSend(input)} className="w-full px-4 py-2 rounded-full bg-input border border-main focus:outline-none focus:ring-2 focus:ring-primary-bg text-text-primary placeholder:text-text-tertiary" placeholder="Ask a question..." />
                    <button onClick={() => handleSend(input)} disabled={isLoading} className="px-4 py-2 text-primary-text bg-primary-bg rounded-full hover:bg-primary-hover disabled:opacity-50">Send</button>
                    </div>
                </div>
            </div>
        </div>
    );
};

// --- QuickCaptureModal Component ---
const QuickCaptureModal = ({ onClose, onCapture }) => {
    const [content, setContent] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [isRecording, setIsRecording] = useState(false);
    const recognitionRef = useRef(null);
    const textareaRef = useRef(null);

    useEffect(() => {
        textareaRef.current?.focus();
    }, []);

    const handleCapture = async () => {
        if (!content.trim()) return;
        setIsLoading(true);
        await onCapture(content);
        setIsLoading(false);
    };
    
    const handleVoiceCapture = () => {
        if (isRecording) {
            recognitionRef.current?.stop();
            setIsRecording(false);
            return;
        }

        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        if (!SpeechRecognition) {
            alert("Speech recognition not supported in this browser.");
            return;
        }

        const recognition = new SpeechRecognition();
        recognition.continuous = true;
        recognition.interimResults = true;
        recognition.lang = 'en-US';

        recognition.onstart = () => setIsRecording(true);
        recognition.onend = () => setIsRecording(false);
        recognition.onerror = (event) => { console.error('Speech recognition error:', event.error); setIsRecording(false); };

        let final_transcript = '';
        recognition.onresult = (event) => {
            let interim_transcript = '';
            for (let i = event.resultIndex; i < event.results.length; ++i) {
                if (event.results[i].isFinal) {
                    final_transcript += event.results[i][0].transcript + ' ';
                } else {
                    interim_transcript += event.results[i][0].transcript;
                }
            }
            // Update textarea with interim and final results
            setContent(final_transcript + interim_transcript);
        };

        recognition.start();
        recognitionRef.current = recognition;
    };


    return (
         <div className={`fixed inset-0 bg-black/60 z-50 flex items-start justify-center pt-20`} onClick={onClose}>
            <div className="bg-sidebar rounded-2xl shadow-xl w-full max-w-xl p-6 border border-main text-text-primary" onClick={e => e.stopPropagation()}>
                <h3 className="text-lg font-medium flex items-center gap-2">⚡ AI Quick Capture</h3>
                <p className="text-sm text-text-secondary mt-1 mb-4">Paste text or record a voice note. AI will automatically title and file it.</p>
                <textarea
                    ref={textareaRef}
                    value={content}
                    onChange={(e) => setContent(e.target.value)}
                    placeholder="Paste anything... or start recording."
                    className="w-full h-48 p-3 rounded-lg bg-input border border-main focus:outline-none focus:ring-2 focus:ring-primary-bg text-text-primary placeholder:text-text-tertiary"
                />
                <div className="mt-6 flex justify-between items-center gap-3">
                    <button 
                        onClick={handleVoiceCapture} 
                        title={isRecording ? "Stop Recording" : "Start Recording"}
                        className={`p-3 rounded-full transition-colors ${isRecording ? 'bg-danger/20 text-danger' : 'bg-hover text-text-primary'}`}
                    >
                       {isRecording ? <MicOffIcon className="h-5 w-5" /> : <MicrophoneIcon className="h-5 w-5"/>}
                    </button>
                    <div className="flex gap-3">
                        <button onClick={onClose} className="px-4 py-2 text-sm font-medium rounded-full hover:bg-hover text-text-primary">Cancel</button>
                        <button onClick={handleCapture} disabled={isLoading || !content.trim()} className="px-4 py-2 text-sm font-medium text-primary-text bg-primary-bg rounded-full hover:bg-primary-hover disabled:opacity-50 min-w-[6rem] flex justify-center">
                            {isLoading ? <Spinner/> : 'Capture'}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};

// --- PresentationModal Component ---
const PresentationModal = ({ note, onClose }) => {
    useEffect(() => {
        const handleKeyDown = (e) => {
            if (e.key === 'Escape') {
                onClose();
            }
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [onClose]);

    return (
        <div 
            className="fixed inset-0 z-50 bg-background text-text-primary p-4 md:p-12 overflow-y-auto" 
            onClick={onClose}
        >
            <button 
                onClick={onClose} 
                className="absolute top-4 right-4 p-2 rounded-full hover:bg-hover text-text-secondary"
                title="Close (Esc)"
            >
                <CloseIcon className="h-6 w-6"/>
            </button>
            <div 
                className="max-w-3xl mx-auto my-12"
                onClick={e => e.stopPropagation()} // Prevent closing when clicking on content
            >
                <h1 className="text-4xl font-bold mb-8 border-b border-main pb-4">{note.title}</h1>
                <div 
                    className="prose prose-lg" 
                    dangerouslySetInnerHTML={{ __html: note.content }} 
                />
            </div>
        </div>
    );
};

// --- KnowledgeGraphModal Component ---
const KnowledgeGraphModal = ({ notes, groups, onClose, onSelectNote, callGeminiAPI }) => {
    const svgRef = useRef(null);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState(null);
    const [d3Loaded, setD3Loaded] = useState(!!window.d3);

    // Load D3.js script
    useEffect(() => {
        if (window.d3) {
            setD3Loaded(true);
            return;
        }
        const script = document.createElement('script');
        script.src = 'https://d3js.org/d3.v7.min.js';
        script.async = true;
        script.onload = () => setD3Loaded(true);
        script.onerror = () => setError('Failed to load visualization library (D3.js).');
        document.body.appendChild(script);

        return () => {
            if (document.body.contains(script)) {
                document.body.removeChild(script);
            }
        }
    }, []);

    // Fetch and render graph
    useEffect(() => {
        if (!d3Loaded || notes.length === 0) return;

        const generateGraph = async () => {
            setIsLoading(true);
            setError(null);
            try {
                const noteSnippets = notes.map(n => ({
                    id: n.id,
                    title: n.title,
                    snippet: n.content.replace(/<[^>]+>/g, ' ').substring(0, 100)
                }));
                
                const systemPrompt = `You are a knowledge graph generator. Here is a list of all notes (ID, title, and content snippet): ${JSON.stringify(noteSnippets)}. Analyze them and generate a list of connections (links) between notes that are conceptually related. Only include strong, relevant connections. Respond *only* with a JSON array of link objects, where each object has a "source" (note ID) and "target" (note ID). Do not include self-references.`;
                
                const payload = {
                    contents: [{ parts: [{ text: "Generate note connections." }] }], // Simple text, system prompt has the data
                    systemInstruction: { parts: [{ text: systemPrompt }] },
                    generationConfig: {
                        responseMimeType: "application/json",
                        responseSchema: {
                            type: "ARRAY",
                            items: {
                                type: "OBJECT",
                                properties: {
                                    source: { type: "STRING" },
                                    target: { type: "STRING" }
                                },
                                required: ["source", "target"]
                            }
                        }
                    }
                };

                const jsonText = await callGeminiAPI(payload);
                const links = JSON.parse(jsonText);

                // Filter links to ensure they are valid
                const validLinks = links.filter(l => 
                    notes.some(n => n.id === l.source) && notes.some(n => n.id === l.target)
                );

                const nodes = notes.map(n => ({ id: n.id, title: n.title, group: n.groupId }));
                
                renderD3Graph(nodes, validLinks);
                setIsLoading(false);

            } catch (err) {
                console.error("Failed to generate graph:", err);
                setError(`Failed to generate graph: ${err.message}`);
                setIsLoading(false);
            }
        };

        generateGraph();

    }, [d3Loaded, notes, groups, callGeminiAPI, onSelectNote]); // Rerun if d3 or notes change

    const renderD3Graph = (nodes, links) => {
        if (!svgRef.current) return;
        const d3 = window.d3;

        const width = svgRef.current.clientWidth;
        const height = svgRef.current.clientHeight;

        d3.select(svgRef.current).selectAll("*").remove(); // Clear previous graph

        const svg = d3.select(svgRef.current)
            .attr("viewBox", [-width / 2, -height / 2, width, height])
            .style("display", "block");

        // Use a color scale for groups
        const groupIds = [...new Set(groups.map(g => g.id))];
        const color = d3.scaleOrdinal(d3.schemeTableau10).domain(groupIds);

        const simulation = d3.forceSimulation(nodes)
            .force("link", d3.forceLink(links).id(d => d.id).distance(100))
            .force("charge", d3.forceManyBody().strength(-200))
            .force("center", d3.forceCenter(0, 0));

        const link = svg.append("g")
            .attr("stroke", "var(--text-tertiary)")
            .attr("stroke-opacity", 0.6)
            .selectAll("line")
            .data(links)
            .join("line");

        const node = svg.append("g")
            .attr("stroke-width", 1.5)
            .selectAll("g")
            .data(nodes)
            .join("g")
            .call(drag(simulation));
            
        node.append("circle")
            .attr("r", 12)
            .attr("fill", d => color(d.group))
            .attr("stroke", "var(--background)")
            .attr("stroke-width", 2)
            .on("click", (event, d) => {
                event.stopPropagation();
                const noteToSelect = notes.find(n => n.id === d.id);
                if(noteToSelect) onSelectNote(noteToSelect);
            });

        node.append("text")
            .attr("x", 15)
            .attr("y", "0.31em")
            .attr("fill", "var(--text-primary)")
            .attr("font-size", "12px")
            .text(d => d.title.substring(0, 20) + (d.title.length > 20 ? '...' : ''))
            .style("pointer-events", "none");
            
        node.append("title")
            .text(d => d.title);

        simulation.on("tick", () => {
            link
                .attr("x1", d => d.source.x)
                .attr("y1", d => d.source.y)
                .attr("x2", d => d.target.x)
                .attr("y2", d => d.target.y);

            node
                .attr("transform", d => `translate(${d.x},${d.y})`);
        });

        // Drag handler
        function drag(simulation) {
            function dragstarted(event, d) {
                if (!event.active) simulation.alphaTarget(0.3).restart();
                d.fx = d.x;
                d.fy = d.y;
            }
            function dragged(event, d) {
                d.fx = event.x;
                d.fy = event.y;
            }
            function dragended(event, d) {
                if (!event.active) simulation.alphaTarget(0);
                d.fx = null;
                d.fy = null;
            }
            return d3.drag()
                .on("start", dragstarted)
                .on("drag", dragged)
                .on("end", dragended);
        }
    };

    return (
        <div className="fixed inset-0 z-50 bg-background/90 backdrop-blur-sm" onClick={onClose}>
            <button 
                onClick={onClose} 
                className="absolute top-4 right-4 p-2 rounded-full hover:bg-hover text-text-secondary"
                title="Close (Esc)"
            >
                <CloseIcon className="h-6 w-6"/>
            </button>
            
            {isLoading && (
                <div className="absolute inset-0 flex flex-col items-center justify-center text-text-primary">
                    <Spinner />
                    <p className="mt-2 text-sm">🧠 Analyzing connections...</p>
                </div>
            )}
            
            {error && (
                <div className="absolute inset-0 flex items-center justify-center text-red-400 p-4">
                    {error}
                </div>
            )}

            <svg ref={svgRef} className="w-full h-full"></svg>
        </div>
    );
};

// --- ProfileModal Component ---
const ProfileModal = ({ onClose, user, onUpdateName, onLogout, theme, onChangeTheme, layoutSettings, onLayoutChange }) => {
    const [name, setName] = useState(user.name);

    const handleSubmit = (e) => {
        e.preventDefault();
        onUpdateName(name);
        onClose();
    };
    
    const handleThemeChange = (e) => {
        onChangeTheme(); // This just cycles, no value needed
    };
    
    const handleLayoutToggle = (key) => {
        onLayoutChange(key, !layoutSettings[key]);
    };

    return (
         <div className={`fixed inset-0 bg-black/60 z-50 flex items-start justify-center pt-20`} onClick={onClose}>
            <div className="bg-sidebar rounded-2xl shadow-xl w-full max-w-md p-6 border border-main text-text-primary" onClick={e => e.stopPropagation()}>
                <h3 className="text-lg font-medium">Profile & Settings</h3>
                
                <form onSubmit={handleSubmit} className="mt-4 space-y-4">
                    <div>
                        <label className="text-sm font-medium text-text-secondary">Display Name</label>
                        <input
                            type="text"
                            value={name}
                            onChange={e => setName(e.target.value)}
                            className="w-full px-3 py-2 mt-1 rounded-lg bg-input border border-main focus:outline-none focus:ring-2 focus:ring-primary-bg text-text-primary"
                        />
                    </div>
                     <div>
                        <label className="text-sm font-medium text-text-secondary">Email</label>
                        <p className="text-sm text-text-primary mt-1">{user.email}</p>
                    </div>
                    <button type="submit" className="px-4 py-2 text-sm font-medium text-primary-text bg-primary-bg rounded-full hover:bg-primary-hover">Save Changes</button>
                </form>

                <div className="mt-6 pt-6 border-t border-main space-y-4">
                    <h4 className="text-sm font-medium text-text-secondary">Theme</h4>
                    <div className="flex gap-2">
                        <button onClick={onChangeTheme} className="flex-1 px-4 py-2 text-sm rounded-full bg-input border border-main hover:bg-hover">
                            Cycle Theme (Current: {theme})
                        </button>
                    </div>
                </div>

                <div className="mt-6 pt-6 border-t border-main">
                    <button onClick={onLogout} className="w-full px-4 py-2 text-sm font-medium rounded-full bg-danger text-white hover:bg-danger-hover">
                        Log Out
                    </button>
                </div>
            </div>
        </div>
    );
};


export default App;

