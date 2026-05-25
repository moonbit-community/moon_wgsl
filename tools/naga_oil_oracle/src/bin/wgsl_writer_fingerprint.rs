use std::env;
use std::fs;
use std::path::PathBuf;

#[derive(Debug)]
struct Options {
    input: PathBuf,
    output: PathBuf,
}

fn usage() -> ! {
    eprintln!("usage: wgsl_writer_fingerprint --input <file.wgsl> --output <fingerprint.txt>");
    std::process::exit(2);
}

fn parse_options() -> Options {
    let mut input = None;
    let mut output = None;
    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--input" => input = args.next().map(PathBuf::from),
            "--output" => output = args.next().map(PathBuf::from),
            _ => usage(),
        }
    }
    Options {
        input: input.unwrap_or_else(|| usage()),
        output: output.unwrap_or_else(|| usage()),
    }
}

fn strip_comments(source: &str) -> String {
    let mut out = String::with_capacity(source.len());
    let mut chars = source.chars().peekable();
    let mut block_depth = 0usize;
    let mut line_comment = false;
    while let Some(ch) = chars.next() {
        let next = chars.peek().copied();
        if line_comment {
            if ch == '\n' || ch == '\r' {
                line_comment = false;
                out.push(ch);
            } else {
                out.push(' ');
            }
            continue;
        }
        if block_depth > 0 {
            if ch == '/' && next == Some('*') {
                chars.next();
                block_depth += 1;
                out.push_str("  ");
            } else if ch == '*' && next == Some('/') {
                chars.next();
                block_depth -= 1;
                out.push_str("  ");
            } else if ch == '\n' || ch == '\r' {
                out.push(ch);
            } else {
                out.push(' ');
            }
            continue;
        }
        if ch == '/' && next == Some('/') {
            chars.next();
            line_comment = true;
            out.push_str("  ");
        } else if ch == '/' && next == Some('*') {
            chars.next();
            block_depth = 1;
            out.push_str("  ");
        } else {
            out.push(ch);
        }
    }
    out
}

fn ident_after_keyword(line: &str, keyword: &str) -> Option<String> {
    let mut rest = line.strip_prefix(keyword)?.trim_start();
    if keyword == "var" && rest.starts_with('<') {
        let mut depth = 0i32;
        let mut end = 0usize;
        for (idx, ch) in rest.char_indices() {
            if ch == '<' {
                depth += 1;
            } else if ch == '>' {
                depth -= 1;
                if depth == 0 {
                    end = idx + ch.len_utf8();
                    break;
                }
            }
        }
        rest = rest[end..].trim_start();
    }
    let name = rest
        .split(|ch: char| !(ch == '_' || ch.is_ascii_alphanumeric()))
        .next()
        .unwrap_or("");
    (!name.is_empty()).then(|| name.to_owned())
}

fn declaration_fingerprint(source: &str) -> Vec<String> {
    let source = strip_comments(source);
    let mut lines = Vec::new();
    let mut depth = 0i32;
    let mut pending_attrs = String::new();
    let mut ordinal = 0usize;

    for raw_line in source.lines() {
        let trimmed = raw_line.trim();
        let depth_before = depth;
        for ch in raw_line.chars() {
            match ch {
                '{' => depth += 1,
                '}' => depth -= 1,
                _ => {}
            }
        }
        if depth_before != 0 || trimmed.is_empty() {
            continue;
        }
        if trimmed.starts_with('@') {
            if !pending_attrs.is_empty() {
                pending_attrs.push(' ');
            }
            pending_attrs.push_str(trimmed);
            continue;
        }
        let mut item = trimmed;
        let attrs = std::mem::take(&mut pending_attrs);
        if !attrs.is_empty() {
            item = trimmed;
        }
        let candidates = [
            ("struct", "struct"),
            ("alias", "alias"),
            ("const_assert", "const_assert"),
            ("const", "const"),
            ("override", "override"),
            ("var", "var"),
            ("fn", "fn"),
            ("enable", "enable"),
            ("requires", "requires"),
            ("diagnostic", "diagnostic"),
        ];
        for (kind, keyword) in candidates {
            if item == keyword
                || item.starts_with(&format!("{keyword} "))
                || item.starts_with(&format!("{keyword}<"))
            {
                let name = if kind == "const_assert" {
                    "<const_assert>".to_owned()
                } else if kind == "enable" || kind == "requires" || kind == "diagnostic" {
                    item.trim_end_matches(';').to_owned()
                } else {
                    ident_after_keyword(item, keyword).unwrap_or_else(|| "<unnamed>".to_owned())
                };
                lines.push(format!("{ordinal:04}\t{kind}\t{name}"));
                ordinal += 1;
                break;
            }
        }
    }

    lines
}

fn main() {
    let options = parse_options();
    let source = fs::read_to_string(&options.input).unwrap_or_else(|err| {
        panic!("failed to read `{}`: {err}", options.input.display());
    });
    let lines = declaration_fingerprint(&source);
    fs::write(&options.output, lines.join("\n") + "\n").unwrap_or_else(|err| {
        panic!("failed to write `{}`: {err}", options.output.display());
    });
}
