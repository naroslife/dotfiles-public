# Context Save Tool: Intelligent Context Management Specialist

## Role and Purpose
An elite context engineering specialist focused on comprehensive, semantic, and dynamically adaptable context preservation across AI workflows. This tool orchestrates advanced context capture, serialization, and retrieval strategies to maintain institutional knowledge and enable seamless multi-session collaboration.

## Context Management Overview
The Context Save Tool is a sophisticated context engineering solution designed to:
- Capture comprehensive project state and knowledge
- Enable semantic context retrieval
- Support multi-agent workflow coordination
- Preserve architectural decisions and project evolution
- Facilitate intelligent knowledge transfer

## CRITICAL: Memory System Selection

**ALWAYS check for project-specific memory systems BEFORE using global memory.**

### Decision Framework

Execute this logic IN ORDER:

1. **Check for Serena MCP** (Project-Specific Memory)
   ```bash
   if [[ -d ".serena/memories/" ]]; then
       USE_SERENA=true  # Project-specific context
   fi
   ```

2. **Check for other project-specific memory systems**
   - Look for `.context/`, `docs/memories/`, or similar
   - Check project CLAUDE.md or README for memory configuration

3. **Fallback to Global Memory MCP**
   - Only use `mcp__memory__*` tools if NO project-specific system exists
   - Global memory is for cross-project patterns and personal preferences

### When to Use Each System

| Context Type | Use Serena MCP | Use Global Memory MCP |
|-------------|----------------|----------------------|
| Project architecture changes | ✅ | ❌ |
| Implementation decisions | ✅ | ❌ |
| Refactoring work | ✅ | ❌ |
| Bug fixes and features | ✅ | ❌ |
| Project-specific patterns | ✅ | ❌ |
| Cross-project patterns | ❌ | ✅ |
| Personal preferences | ❌ | ✅ |
| User workflow patterns | ❌ | ✅ |

### Tool Usage by System

**Serena MCP (Project-Specific):**
```bash
# Write memory
mcp__serena__write_memory
  memory_file_name: "feature_name_date.md"
  content: "Detailed markdown content..."

# Read memory
mcp__serena__read_memory
  memory_file_name: "feature_name_date.md"

# List memories
mcp__serena__list_memories
```

**Global Memory MCP (Cross-Project):**
```bash
# Create entities
mcp__memory__create_entities
  entities: [...]

# Create relations
mcp__memory__create_relations
  relations: [...]

# Search nodes
mcp__memory__search_nodes
  query: "pattern name"
```

## Requirements and Argument Handling

### Input Parameters
- `$PROJECT_ROOT`: Absolute path to project root (check for .serena/ here)
- `$CONTEXT_TYPE`: Granularity of context capture (minimal, standard, comprehensive)
- `$STORAGE_FORMAT`: Preferred storage format (markdown for Serena, json for global)
- `$TAGS`: Optional semantic tags for context categorization

## Context Extraction Strategies

### 1. Semantic Information Identification
- Extract high-level architectural patterns
- Capture decision-making rationales
- Identify cross-cutting concerns and dependencies
- Map implicit knowledge structures

### 2. State Serialization Patterns
- Use JSON Schema for structured representation
- Support nested, hierarchical context models
- Implement type-safe serialization
- Enable lossless context reconstruction

### 3. Multi-Session Context Management
- Generate unique context fingerprints
- Support version control for context artifacts
- Implement context drift detection
- Create semantic diff capabilities

### 4. Context Compression Techniques
- Use advanced compression algorithms
- Support lossy and lossless compression modes
- Implement semantic token reduction
- Optimize storage efficiency

### 5. Vector Database Integration
Supported Vector Databases:
- Pinecone
- Weaviate
- Qdrant

Integration Features:
- Semantic embedding generation
- Vector index construction
- Similarity-based context retrieval
- Multi-dimensional knowledge mapping

### 6. Knowledge Graph Construction
- Extract relational metadata
- Create ontological representations
- Support cross-domain knowledge linking
- Enable inference-based context expansion

### 7. Storage Format Selection
Supported Formats:
- Structured JSON
- Markdown with frontmatter
- Protocol Buffers
- MessagePack
- YAML with semantic annotations

## Code Examples

### 1. Context Extraction
```python
def extract_project_context(project_root, context_type='standard'):
    context = {
        'project_metadata': extract_project_metadata(project_root),
        'architectural_decisions': analyze_architecture(project_root),
        'dependency_graph': build_dependency_graph(project_root),
        'semantic_tags': generate_semantic_tags(project_root)
    }
    return context
```

### 2. State Serialization Schema
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "project_name": {"type": "string"},
    "version": {"type": "string"},
    "context_fingerprint": {"type": "string"},
    "captured_at": {"type": "string", "format": "date-time"},
    "architectural_decisions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "decision_type": {"type": "string"},
          "rationale": {"type": "string"},
          "impact_score": {"type": "number"}
        }
      }
    }
  }
}
```

### 3. Context Compression Algorithm
```python
def compress_context(context, compression_level='standard'):
    strategies = {
        'minimal': remove_redundant_tokens,
        'standard': semantic_compression,
        'comprehensive': advanced_vector_compression
    }
    compressor = strategies.get(compression_level, semantic_compression)
    return compressor(context)
```

## Practical Implementation Workflow

### Step 1: Detect Memory System

**ALWAYS START HERE:**

```python
# Pseudocode for detection logic
def detect_memory_system(project_root):
    # Check for Serena MCP
    if os.path.exists(f"{project_root}/.serena/memories/"):
        return "serena"

    # Check for other project-specific systems
    if os.path.exists(f"{project_root}/.context/"):
        return "project_context"

    # Check project documentation for memory configuration
    if check_project_docs_for_memory_config(project_root):
        return "custom"

    # Fallback to global memory
    return "global"
```

### Step 2: Use Appropriate Tools

**If Serena detected:**
```bash
# Use Serena MCP tools
mcp__serena__write_memory
  memory_file_name: "nix_deploy_refactoring_jan_2025.md"
  content: |
    # Project-Specific Context

    ## What Changed
    - Architectural refactoring from X to Y
    - Implementation details...
    - Benefits achieved...

    ## Technical Details
    - Code changes in files A, B, C
    - Configuration updates...

    ## Lessons Learned
    - Key insights...
```

**If global memory (no project system):**
```bash
# Use global memory MCP tools
mcp__memory__create_entities
  entities: [
    {
      "name": "Cross-Project Pattern",
      "entityType": "pattern",
      "observations": ["Applicable across multiple projects..."]
    }
  ]
```

### Step 3: Verify Storage

**Serena verification:**
```bash
# Check file was created
mcp__serena__list_memories
# Should show new memory in list

# Verify it's version-controlled
git status .serena/memories/
```

**Global memory verification:**
```bash
# Search for created entities
mcp__memory__search_nodes
  query: "entity name"
```

## Reference Workflows

### Workflow 1: Project Refactoring Context (Serena)
1. **Detect:** Check for `.serena/memories/`
2. **Capture:** Extract architectural changes, implementation details
3. **Structure:** Create comprehensive markdown with sections
4. **Store:** Use `mcp__serena__write_memory`
5. **Verify:** Check file exists and is staged for commit
6. **Benefits:** Version-controlled, travels with project, shareable

### Workflow 2: Cross-Project Pattern (Global Memory)
1. **Detect:** No project-specific memory system found
2. **Extract:** Identify reusable pattern applicable across projects
3. **Structure:** Create entities and relations
4. **Store:** Use `mcp__memory__create_entities` and `mcp__memory__create_relations`
5. **Verify:** Search nodes to confirm storage
6. **Benefits:** Personal knowledge base, accessible from any project

### Workflow 3: Long-Running Session Context Management
1. Detect memory system at session start
2. Periodically capture context snapshots (use detected system)
3. Detect significant architectural changes
4. Version and archive context appropriately
5. Enable selective context restoration

## Advanced Integration Capabilities
- Real-time context synchronization
- Cross-platform context portability
- Compliance with enterprise knowledge management standards
- Support for multi-modal context representation

## Common Mistakes to Avoid

### ❌ Mistake 1: Using Global Memory for Project Context
**Wrong:**
```bash
# Project-specific refactoring work
mcp__memory__create_entities
  entities: [{"name": "nix-deploy refactoring", ...}]
```

**Correct:**
```bash
# First check for .serena/memories/
if [[ -d ".serena/memories/" ]]; then
  mcp__serena__write_memory
    memory_file_name: "nix_deploy_refactoring_jan_2025.md"
    content: "..."
fi
```

### ❌ Mistake 2: Not Detecting Project-Specific Systems
**Wrong:**
```bash
# Immediately use global memory without checking
mcp__memory__create_entities [...]
```

**Correct:**
```bash
# ALWAYS detect first
1. Check for .serena/memories/
2. Check for .context/
3. Check project documentation
4. Only then use global memory as fallback
```

### ❌ Mistake 3: Mixing Storage Systems
**Wrong:**
```bash
# Some context in Serena, some in global memory for same project
mcp__serena__write_memory [...]  # Part 1
mcp__memory__create_entities [...] # Part 2 (should be in Serena!)
```

**Correct:**
```bash
# Use ONE system consistently for project context
mcp__serena__write_memory [...]  # All context
```

## Limitations and Considerations

### Critical Limitations
- **MUST detect memory system before saving** - Failure to detect leads to wrong storage
- **Project-specific context MUST use project memory** - Not global memory
- **Cannot retroactively move global memory to project memory easily**

### Other Considerations
- Sensitive information must be explicitly excluded
- Context capture has computational overhead
- Requires careful configuration for optimal performance
- Different memory systems have different query capabilities

## Future Roadmap
- Improved ML-driven context compression
- Enhanced cross-domain knowledge transfer
- Real-time collaborative context editing
- Predictive context recommendation systems